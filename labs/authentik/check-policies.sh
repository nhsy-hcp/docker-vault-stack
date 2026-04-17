#!/bin/bash
set -euo pipefail

# Script to check current Vault token policies and group memberships

echo "=== Vault Token Policy Checker ==="
echo ""

# Check if Vault is accessible
if ! vault status &>/dev/null; then
    echo "❌ Error: Vault is not accessible at $VAULT_ADDR"
    echo "Please ensure Vault is running and VAULT_ADDR is set correctly."
    exit 1
fi

# Check if logged in
if ! vault token lookup &>/dev/null; then
    echo "❌ Error: Not logged in to Vault"
    echo "Please run 'vault login' first or use './demo-auth.sh' to authenticate."
    exit 1
fi

echo "✅ Connected to Vault"
echo ""

# Get token information
echo "=== Current Token Information ==="
vault token lookup | grep -E "(accessor|display_name|entity_id|policies|ttl|creation_time)"
echo ""

# Get entity ID
ENTITY_ID=$(vault token lookup -format=json | jq -r '.data.entity_id')

if [ "$ENTITY_ID" = "null" ] || [ -z "$ENTITY_ID" ]; then
    echo "⚠️  No entity associated with this token"
    echo "This might be a root token or a token without identity."
    exit 0
fi

echo "=== Entity Information ==="
echo "Entity ID: $ENTITY_ID"
echo ""

# Get entity details
echo "Entity Details:"
vault read identity/entity/id/"$ENTITY_ID" -format=json | jq -r '
    .data |
    "Name: \(.name)",
    "Aliases: \(.aliases | length)",
    "Direct Policies: \(.policies // [] | join(", "))",
    "Group IDs: \(.group_ids // [] | length)"
'
echo ""

# Get group memberships
echo "=== Group Memberships ==="
GROUP_IDS=$(vault read identity/entity/id/"$ENTITY_ID" -format=json | jq -r '.data.group_ids[]?' 2>/dev/null)

if [ -z "$GROUP_IDS" ]; then
    echo "No group memberships found"
else
    for group_id in $GROUP_IDS; do
        echo "---"
        vault read identity/group/id/"$group_id" -format=json 2>/dev/null | jq -r '
            .data |
            "Group Name: \(.name)",
            "Type: \(.type)",
            "Policies: \(.policies // [] | join(", "))",
            "Namespace: \(.namespace_id // "root")"
        ' || echo "Could not read group: $group_id"
    done
fi

echo ""
echo "=== Effective Policies ==="
echo "The following policies are effective for your current token:"
vault token lookup -format=json | jq -r '.data.policies[]'

echo ""
echo "=== Policy Details ==="
read -r -p "Would you like to view policy contents? [y/N]: " view_policies

if [[ "$view_policies" =~ ^[Yy]$ ]]; then
    POLICIES=$(vault token lookup -format=json | jq -r '.data.policies[]')
    for policy in $POLICIES; do
        echo ""
        echo "=== Policy: $policy ==="
        vault policy read "$policy" 2>/dev/null || echo "Could not read policy: $policy"
    done
fi

echo ""
echo "=== Summary ==="
echo "✅ Token is valid and associated with entity: $ENTITY_ID"
echo "✅ Group memberships and policies retrieved successfully"
echo ""
