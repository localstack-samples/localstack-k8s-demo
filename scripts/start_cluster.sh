#!/usr/bin/env bash

set -euo pipefail


reset() {
    minikube delete 2>/dev/null
}

start() {
    minikube start --nodes 1 --cpus max --embed-certs true --memory max
}

taint() {
    kubectl taint nodes minikube node-role.kubernetes.io/master:NoSchedule --overwrite
    kubectl drain minikube --ignore-daemonsets --force
}

pull-image() {
    local imageName="$1"
    echo "Pulling $imageName"
    minikube image pull "$imageName"
}

pull-images() {
    echo "Pushing Docker images"
    pull-image ghcr.io/simonrw/docker-debug:main
    pull-image docker.io/localstack/lambda-python:3.12
    pull-image docker.io/localstack/localstack-pro:latest
    pull-image docker.io/library/mysql:8.4.5
    pull-image gcr.io/kubebuilder/kube-rbac-proxy:v0.15.0
    pull-image localstack/localstack-k8s-operator:v0.3.3
}

reset
start
pull-images
# taint
