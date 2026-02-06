#!/usr/bin/env bash
set -euo pipefail
IMAGE="$1"
if ! command -v trivy >/dev/null 2>&1; then
  echo "trivy not found; please install trivy on the agent"
  exit 1
fi
trivy image --severity HIGH,CRITICAL "$IMAGE"
