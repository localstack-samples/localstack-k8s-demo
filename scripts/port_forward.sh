#!/usr/bin/env bash

set -euo pipefail

kubectl port-forward -n workspace svc/localstack-env-1 4566
