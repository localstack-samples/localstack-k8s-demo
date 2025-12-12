#!/usr/bin/env bash

set -euo pipefail

if test -z ${LOCALSTACK_AUTH_TOKEN:-}; then
    echo "LOCALSTACK_AUTH_TOKEN not set" >&2
    exit 1
fi

SECRET_NAME=localstack-auth-token
NAMESPACE=workspace
mode=$1

case "$mode" in
    deploy)
        echo cleanup
        bash $0 destroy
        echo deploying
        kubectl create namespace $NAMESPACE 2>/dev/null || true
        kubectl create secret -n $NAMESPACE generic $SECRET_NAME --from-literal=LOCALSTACK_AUTH_TOKEN=$LOCALSTACK_AUTH_TOKEN
        ;;
    destroy)
        echo destroying
        kubectl delete secret -n $NAMESPACE $SECRET_NAME 2>/dev/null || true
        ;;
esac
