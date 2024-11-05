#!/usr/bin/env bash
export VAULT_ADDR=http://127.0.0.1:8200

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
