#!/usr/bin/env bash
# Check the demo works end to end:
# 1. LocalStack answers through the port forward
# 2. the Lambda function connects to the RDS MySQL database and returns the two rows it inserted
# 3. LocalStack ran the database and the function as pods in the cluster
set -euo pipefail

NAMESPACE=${NAMESPACE:-workspace}
ENDPOINT=${ENDPOINT:-http://localhost:4566}
AWS=${AWS_CMD:-aws}

if ! curl -sf -m 10 "$ENDPOINT/_localstack/health" > /dev/null; then
  echo "Test failed: LocalStack is not reachable at $ENDPOINT. Run 'make port-forward' first."
  exit 1
fi
echo "PASS: LocalStack answers at $ENDPOINT"

status=$($AWS rds describe-db-instances --db-instance-identifier k8sdb \
  --query 'DBInstances[0].DBInstanceStatus' --output text)
if [ "$status" != "available" ]; then
  echo "Test failed: database k8sdb is $status, expected available"
  exit 1
fi
echo "PASS: database k8sdb is available"

# The first invocation starts the Lambda pod, which can take a while
out=$(mktemp)
meta=$($AWS lambda invoke --function-name myfunction --payload '{}' \
  --cli-read-timeout 300 "$out")
echo "$meta"
echo "Response: $(cat "$out")"
if echo "$meta" | jq -e '.FunctionError' > /dev/null; then
  echo "Test failed: the function returned an error"
  exit 1
fi
if ! jq -e '.results == [[1, "test"], [2, "another"]]' "$out" > /dev/null; then
  echo "Test failed: expected the rows [1, \"test\"] and [2, \"another\"] from the database"
  exit 1
fi
echo "PASS: the function queried the database and returned both rows"

pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
echo "Pods in $NAMESPACE:"
echo "$pods"
for prefix in lambda-myfunction- ls-mysql-; do
  if ! echo "$pods" | grep -q "^$prefix"; then
    echo "Test failed: no pod named $prefix* in namespace $NAMESPACE"
    exit 1
  fi
done
echo "PASS: the database and the function run as pods in the cluster"

echo "Test passed: the Lambda pod queried the MySQL pod through LocalStack in Kubernetes"
