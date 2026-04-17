#!/bin/bash
set -euo pipefail

# Demo script for testing Authentik OIDC authentication with Vault

echo "=== Authentik OIDC Authentication Demo ==="
echo ""

# Check if Vault is accessible
if ! vault status &>/dev/null; then
    echo "❌ Error: Vault is not accessible at $VAULT_ADDR"
    echo "Please ensure Vault is running and VAULT_ADDR is set correctly."
    exit 1
fi

# Check if Authentik is accessible
if ! curl -sf http://localhost:9000/-/health/live/ &>/dev/null; then
    echo "❌ Error: Authentik is not accessible at http://localhost:9000"
    echo "Please ensure Authentik is running."
    exit 1
fi

echo "✅ Vault and Authentik are accessible"
echo ""

# Function to test authentication in a namespace
test_auth() {
    local namespace=$1
    local description=$2

    echo "=== Testing: $description ==="
    echo "Namespace: ${namespace:-root}"
    echo ""

    if [ -z "$namespace" ]; then
        echo "Running: vault login -method=oidc role=default"
        vault login -method=oidc role=default
    else
        echo "Running: vault login -namespace=$namespace -method=oidc role=default"
        vault login -namespace="$namespace" -method=oidc role=default
    fi

    echo ""
    echo "✅ Authentication successful!"
    echo ""

    # Show token info
    echo "Token information:"
    if [ -z "$namespace" ]; then
        vault token lookup | grep -E "(display_name|policies|entity_id)"
    else
        vault token lookup -namespace="$namespace" | grep -E "(display_name|policies|entity_id)"
    fi

    echo ""
    echo "---"
    echo ""
}

# Main menu
echo "Select authentication test:"
echo "1) Root namespace (vault-admin group)"
echo "2) Admin namespace (vault-user group)"
echo "3) Test secret access (vault-tn001-team1-reader group)"
echo "4) All tests"
echo ""

# Accept choice as command-line argument, default to 1
choice=${1:-}
if [ -z "$choice" ]; then
    read -r -p "Enter choice [1-4]: " choice
else
    echo "Using provided choice: $choice"
fi

case $choice in
    1)
        test_auth "" "Root Namespace - Admin Access"
        ;;
    2)
        test_auth "admin" "Admin Namespace - User Access"
        ;;
    3)
        echo "=== Testing Secret Access ==="
        echo "First, authenticate to admin namespace..."
        echo ""
        test_auth "admin" "Admin Namespace - User Access"

        echo "=== Attempting to read secrets ==="
        echo ""

        echo "Reading: vault kv get -namespace=admin/tn001 team1/app1"
        if vault kv get -namespace=admin/tn001 team1/app1; then
            echo "✅ Successfully read app1 secret"
        else
            echo "❌ Failed to read app1 secret"
        fi

        echo ""
        echo "Reading: vault kv get -namespace=admin/tn001 team1/app2"
        if vault kv get -namespace=admin/tn001 team1/app2; then
            echo "✅ Successfully read app2 secret"
        else
            echo "❌ Failed to read app2 secret"
        fi
        ;;
    4)
        test_auth "" "Root Namespace - Admin Access"
        sleep 2
        test_auth "admin" "Admin Namespace - User Access"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=== Demo Complete ==="
echo ""
echo "To check your current token details, run:"
echo "  ./check-policies.sh"
echo ""
