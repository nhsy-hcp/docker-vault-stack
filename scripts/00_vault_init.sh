#!/usr/bin/env bash
set -o pipefail

export VAULT_ADDR=http://127.0.0.1:8200
vault status

if [ -f "vault-init.json" ]; then
    echo "vault-init.json already exists. This means Vault has already been initialized."
    read -p "Do you want to continue and reinitialize Vault? This will overwrite existing keys (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Initialization cancelled."
        exit 1
    fi
fi

vault operator init -format=json | tee vault-init.json
sed -i '' "s/VAULT_TOKEN=.*/VAULT_TOKEN=$(jq -r '.root_token' vault-init.json)/g" .env
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
vault write sys/quotas/config enable_rate_limit_audit_logging=true
echo "Vault initialised, unsealed and audit logs enabled"
