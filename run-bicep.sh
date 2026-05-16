#!/bin/bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <resource-group>" >&2
  exit 1
fi

# Execute the bicep file deployment using the generated parameters file to deploy the API
az deployment group create \
  --resource-group "$1" \
  --template-file main.bicep \
  --parameters generated.bicepparam
