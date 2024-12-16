# LocalStack Kubernetes Integration Demo

This repo contains a demo of LocalStack running in Kubernetes. The demo includes:

- A MySQL database
- A Lambda function that connects to the database and performs a demonstration query
- Terraform code to deploy the infrastructure
- A Makefile and scripts to deploy everything

This demo is meant to highlight how LocalStack supports both Kubernetes and Docker environments.

```mermaid
architecture-beta
    group api(cloud)[VPC]

    service db(server)[Database] in api
    service server(server)[Lambda] in api

    server:R --> L:db
```

> [!NOTE]
> LocalStack's Kubernetes integration is only available on our Enterprise tier.

## Setup

- Make sure your `LOCALSTACK_AUTH_TOKEN` is in your shell environment
- Install
  - [`minikube`](https://minikube.sigs.k8s.io/docs/start/) but any local Kubernetes cluster will work
  - [`tflocal`](https://docs.localstack.cloud/user-guide/integrations/terraform/)
  - [`terraform`](https://www.terraform.io/downloads) or [`opentofu`](https://opentofu.org/downloads) (if using `tofu`, set `TF_CMD=tofu`)
  - [`kubectl`](https://kubernetes.io/docs/reference/kubectl/)
  - [`helm`](https://helm.sh/docs/intro/install/)
  - (optional) [`k9s`](https://k9scli.io/)
- Install Python dependencies into a virtual environment: `python -m venv .venv && .venv/bin/python -m pip install -r requirements.txt && source .venv/bin/activate`
- Run `make init` to set up the terraform providers

## Walkthrough

1. Deploy the cluster: `make start`
   - This starts a local Kubernetes cluster using `minikube` and fetches the Docker images for LocalStack and the demo application
2. Deploy LocalStack: `make deploy-localstack`
   - This installs LocalStack into the Kubernetes cluster using `helm`
3. Deploy application: `make reset apply`
   - This resets the terraform state and applies the Terraform configuration, which creates the database and Lambda function
4. Invoke the lambda function: `make invoke`
   - This invokes the Lambda function and demonstrates that it can connect to the database

## Cleanup

- To remove LocalStack from the Kubernetes cluster, run `helm uninstall localstack`
- For removal of the Kubernetes cluster as well, run `minikube delete` to delete the local Kubernetes cluster
