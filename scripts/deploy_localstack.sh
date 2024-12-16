#!/usr/bin/env bash

set -euo pipefail

install_repo() {
    helm repo add localstack https://localstack.github.io/helm-charts --force-update
}

install_localstack_into_cluster() {
    helm upgrade \
        --install \
        localstack \
        localstack/localstack \
        --values values.yml \
        --set extraEnvVars[1].name=LOCALSTACK_AUTH_TOKEN \
        --set extraEnvVars[1].value=$LOCALSTACK_AUTH_TOKEN \
        --wait
}

install_repo
install_localstack_into_cluster
