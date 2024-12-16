#!/usr/bin/env bash

set -euo pipefail

kubectl port-forward services/localstack 4566
