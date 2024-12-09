#!/usr/bin/env bash
set -o pipefail

export VAULT_ADDR=http://127.0.0.1:8200
vault status
vault operator init -format=json | tee vault-init.json
echo "Waiting for Vault to initialise..."
sleep 20
echo "Unsealing vault..."
export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')
vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
vault status
vault audit enable -path="audit_log" file file_path=/vault/logs/vault_audit.log
vault audit enable -path="audit_stdout" file file_path=stdout
echo "Vault initialised, unsealed and audit logs enabled"
