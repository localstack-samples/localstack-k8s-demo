OPERATOR_VERSION ?= latest

usage:                    ## Show this help
	@grep -Fh "##" $(MAKEFILE_LIST) | grep -Fv fgrep | sed -e 's/:.*##\s*/##/g' | awk -F'##' '{ printf "%-25s %s\n", $$1, $$2 }'

start: start-cluster

start-cluster:
	bash ./scripts/start_cluster.sh

deploy-operator:
	kubectl apply --server-side -f https://github.com/localstack/localstack-operator/releases/${OPERATOR_VERSION}/download/controller.yaml

destroy-operator:
	kubectl delete -f  https://github.com/localstack/localstack-operator/releases/${OPERATOR_VERSION}/download/controller.yaml

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
	AWS_PROFILE=localstack tflocal init

plan:  ## Execute terraform plan
	AWS_PROFILE=localstack tflocal plan

apply:  ## Deploy terraform application
	AWS_PROFILE=localstack tflocal apply -auto-approve

destroy-app:  ## Destroy the application
	AWS_PROFILE=localstack tflocal apply -destroy -auto-approve

reset: ## Reset terraform state
	rm -f terraform.tfstate terraform.tfstate.backup

invoke: ## Invoke the deployed lambda function
	@cat scripts/lambda_message.txt | glow
	AWS_PROFILE=localstack aws lambda invoke --function-name myfunction --payload '{}' /dev/stdout | jq .

.PHONY: apply plan reset invoke init
