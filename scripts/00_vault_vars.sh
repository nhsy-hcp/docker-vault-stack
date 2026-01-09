#!/usr/bin/env bash

set -o pipefail

# Verify VAULT_ADDR is set (should be loaded by Taskfile from .env)
if [ -z "$VAULT_ADDR" ]; then
    echo "Error: VAULT_ADDR not set"
    echo "Please ensure .env file exists with: export VAULT_ADDR=http://localhost:8200"
    echo "Run: source .env"
    exit 1
fi

export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')
echo
echo export VAULT_ADDR=$VAULT_ADDR
echo export VAULT_TOKEN=$VAULT_TOKEN

if [[ "$OSTYPE" =~ ^darwin ]]; then
  echo $VAULT_TOKEN | pbcopy
  echo "Vault token copied to clipboard"
fi
