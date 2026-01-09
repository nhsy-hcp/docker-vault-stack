#!/usr/bin/env bash

# Verify VAULT_ADDR is set (should be loaded by Taskfile from .env)
if [ -z "$VAULT_ADDR" ]; then
    echo "Error: VAULT_ADDR not set"
    echo "Please ensure .env file exists with: export VAULT_ADDR=http://localhost:8200"
    echo "Run: source .env"
    exit 1
fi

export VAULT_CACERT=${PWD}/volumes/vault/ca.crt

vault status
sleep 3
echo "Unsealing vault..."
vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
vault status
export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')
echo
echo "Vault is unsealed and ready to use."
echo VAULT_ADDR: $VAULT_ADDR
echo VAULT_TOKEN: $VAULT_TOKEN
