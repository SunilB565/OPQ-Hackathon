#!/usr/bin/env bash
set -euo pipefail
DIR=${1:-terraform}
if ! command -v checkov >/dev/null 2>&1; then
  echo "checkov not found; please install checkov on the agent"
  exit 1
fi
checkov -d "$DIR"
