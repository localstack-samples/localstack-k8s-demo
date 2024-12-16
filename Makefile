usage:                    ## Show this help
	@grep -Fh "##" $(MAKEFILE_LIST) | grep -Fv fgrep | sed -e 's/:.*##\s*/##/g' | awk -F'##' '{ printf "%-25s %s\n", $$1, $$2 }'

start: start-cluster deploy-operator

start-cluster:
	bash ./scripts/start_cluster.sh

deploy-localstack:
	bash ./scripts/deploy_localstack.sh

deploy-operator:
	docker build -t ls-operator .
	minikube image load ls-operator
	kubectl apply -f ./operator.yml

k9s:
	k9s --logoless -r 1 --headless --crumbsless -A

debug-dns:
	kubectl run -i --tty --rm debug --image ghcr.io/simonrw/docker-debug:main --restart=Never -- dig +short localhost.localstack.cloud

logs: ## Show localstack logs
	while ! kubectl logs -f service/localstack 2>/dev/null; do sleep 5; done

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

reset: ## Reset terraform state
	rm -f terraform.tfstate terraform.tfstate.backup

invoke: ## Invoke the deployed lambda function
	@cat scripts/lambda_message.txt | glow
	AWS_PROFILE=localstack aws lambda invoke --function-name myfunction --payload '{}' /dev/stdout | jq .

.PHONY: apply plan reset invoke init
