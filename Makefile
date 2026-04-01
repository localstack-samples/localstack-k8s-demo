TF_CMD ?= terraform
OPERATOR_VERSION ?= v0.4.3
CLUSTER_NAME ?= ls-k8s-demo

usage:                    ## Show this help
	@grep -Fh "##" $(MAKEFILE_LIST) | grep -Fv fgrep | sed -e 's/:.*##\s*/##/g' | awk -F'##' '{ printf "%-25s %s\n", $$1, $$2 }'

start: start-cluster

stop: stop-cluster

start-cluster:
	kind create cluster --name $(CLUSTER_NAME)

stop-cluster:
	kind delete cluster --name $(CLUSTER_NAME)

deploy-operator:
	kubectl apply --server-side -f https://raw.githubusercontent.com/localstack/localstack-operator/${OPERATOR_VERSION}/controller.yaml

destroy-operator:
	kubectl delete -f https://raw.githubusercontent.com/localstack/localstack-operator/${OPERATOR_VERSION}/controller.yaml

deploy-localstack-instance: deploy-secret
	kubectl apply --server-side -f ./localstack-instance.yml

destroy-localstack-instance: destroy-secret
	kubectl delete -f ./localstack-instance.yml

deploy-secret:
	bash ./scripts/manage_secret.sh deploy

destroy-secret:
	bash ./scripts/manage_secret.sh destroy

k9s:
	k9s --logoless -r 1 --headless --crumbsless -A

debug-container:
	kubectl run -i --tty --rm debug-$(shell uuidgen) --image ghcr.io/simonrw/docker-debug:main --restart=Never -- sh

logs: ## Show localstack logs
	while ! kubectl logs -n workspace -f svc/localstack-env-1 2>/dev/null; do sleep 5; done

watchpods:
	watch -n 1 kubectl get pods -A

port-forward: ## Forward the LocalStack port to the host
	while ! bash ./scripts/port_forward.sh; do sleep 5; done

init:  ## Set up terraform project
	${TF_CMD} init

plan:  ## Execute terraform plan
	${TF_CMD} plan

apply:  ## Deploy terraform application
	${TF_CMD} apply -auto-approve

destroy-app:  ## Destroy the application
	${TF_CMD} apply -destroy -auto-approve

reset: ## Reset terraform state
	rm -f terraform.tfstate terraform.tfstate.backup

invoke: ## Invoke the deployed lambda function
	@cat scripts/lambda_message.txt
	aws lambda invoke --function-name myfunction --payload '{}' /dev/stdout | jq .

.PHONY: apply plan reset invoke init
