#!/usr/bin/env bash

set -o pipefail

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')
echo
echo export VAULT_ADDR=$VAULT_ADDR
echo export VAULT_TOKEN=$VAULT_TOKEN

if [[ "$OSTYPE" =~ ^darwin ]]; then
  echo $VAULT_TOKEN | pbcopy
  echo "Vault token copied to clipboard"
fi
