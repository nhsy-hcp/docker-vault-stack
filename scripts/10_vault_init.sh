#!/usr/bin/env bash
set -o pipefail

# Verify VAULT_ADDR is set (should be loaded by Taskfile from .env)
if [ -z "$VAULT_ADDR" ]; then
    echo "Error: VAULT_ADDR not set"
    echo "Please ensure .env file exists with: export VAULT_ADDR=http://localhost:8200"
    echo "Run: source .env"
    exit 1
fi

# Check if Vault is accessible
echo "Checking Vault connectivity..."
max_attempts=5
attempt=1

while [ $attempt -le $max_attempts ]; do
    # vault status returns exit code 0 (unsealed), 1 (error), or 2 (sealed)
    # Both 0 and 2 mean Vault is accessible
    vault status >/dev/null 2>&1
    status_code=$?

    if [ $status_code -eq 0 ] || [ $status_code -eq 2 ]; then
        echo "Vault is accessible."
        break
    fi

    if [ $attempt -eq $max_attempts ]; then
        echo "Error: Vault is not accessible at $VAULT_ADDR"
        echo "Please ensure Vault is running with 'task up' before initializing."
        exit 1
    fi

    echo "Attempt $attempt/$max_attempts: Waiting for Vault to become available..."
    sleep 2
    attempt=$((attempt + 1))
done

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
#echo "Unsealing vault..."
#export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')
#vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
#vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
#vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
#vault status

