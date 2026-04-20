#!/usr/bin/env bash
set -euo pipefail

# Verify VAULT_ADDR is set (should be loaded by Taskfile from .env)
if [ -z "$VAULT_ADDR" ]; then
    echo "Error: VAULT_ADDR not set"
    echo "Please ensure .env file exists with: export VAULT_ADDR=http://vault.localhost:8200"
    echo "Run: source .env"
    exit 1
fi

# Check if vault-init.json exists
if [ ! -f "vault-init.json" ]; then
    echo "Error: vault-init.json not found"
    echo "Vault has not been initialized yet. Run 'task init' first."
    exit 1
fi

# Check vault status
echo "Checking Vault status..."
if ! vault_status_output=$(vault status 2>&1); then
    # Check if Vault is unavailable
    if echo "$vault_status_output" | grep -q "connection refused\|no such host\|timeout"; then
        echo "Error: Vault is unavailable at $VAULT_ADDR"
        echo "Please ensure Vault is running with 'task up'"
        exit 1
    fi

    # Check if Vault is not initialized
    if echo "$vault_status_output" | grep -q "not been initialized\|Vault is not initialized"; then
        echo "Error: Vault is not initialized"
        echo "Run 'task init' to initialize Vault first"
        exit 1
    fi
fi

# Check if Vault is sealed by parsing the output
if echo "$vault_status_output" | grep -q "Sealed.*true"; then
    echo "Vault is sealed. Proceeding with unseal operation..."
elif echo "$vault_status_output" | grep -q "Sealed.*false"; then
    echo "Vault is already unsealed. Nothing to do."
    VAULT_TOKEN=$(jq -r '.root_token' vault-init.json)
    export VAULT_TOKEN
    echo
    echo "Vault status:"
    vault status
    echo
    echo "VAULT_ADDR: $VAULT_ADDR"
    echo "VAULT_TOKEN: $VAULT_TOKEN"
    exit 0
else
    echo "Error: Unable to determine Vault seal status"
    echo "$vault_status_output"
    exit 1
fi

# Proceed with unsealing
echo "Unsealing vault..."
vault operator unseal "$(jq -r '.unseal_keys_b64[0]' vault-init.json)"
vault operator unseal "$(jq -r '.unseal_keys_b64[1]' vault-init.json)"
vault operator unseal "$(jq -r '.unseal_keys_b64[2]' vault-init.json)"

echo
echo "Vault unsealed successfully!"
vault status

VAULT_TOKEN=$(jq -r '.root_token' vault-init.json)
export VAULT_TOKEN
echo
echo "VAULT_ADDR: $VAULT_ADDR"
echo "VAULT_TOKEN: $VAULT_TOKEN"
