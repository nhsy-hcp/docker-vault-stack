#!/usr/bin/env bash
# test-scim.sh — Verify Vault SCIM provisioning from Authentik
# Usage: ./test-scim.sh
set -euo pipefail

# shellcheck source=../../.env
source ../../.env

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

if [ -z "${VAULT_ADDR}" ] || [ -z "${VAULT_TOKEN}" ]; then
  echo "ERROR: VAULT_ADDR and VAULT_TOKEN must be set in .env"
  exit 1
fi

SCIM_TOKEN=$(terraform output -raw scim_bearer_token 2>/dev/null || true)

if [ -z "${SCIM_TOKEN}" ]; then
  echo "ERROR: SCIM bearer token not found. Apply Terraform with enable_scim=true first."
  exit 1
fi

FAILED=0
pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*"; FAILED=1; }

check_status() {
  local label="$1" status="$2"
  if [ "${status}" = "200" ]; then
    pass "${label} reachable (HTTP ${status})"
  else
    fail "${label} returned HTTP ${status}"
  fi
}

check_count() {
  local label="$1" count="$2"
  if [ "${count}" -gt 0 ]; then
    pass "${label}: ${count}"
  else
    fail "${label}: none found"
  fi
}

echo ""
echo "=== Vault SCIM Lab - Verification ==="
echo ""

# ---------------------------------------------------------------------------
# Root namespace
# ---------------------------------------------------------------------------
echo "── Root namespace ──────────────────────────────"

STATUS=$(curl -sf -o /dev/null -w "%{http_code}" \
  -H "X-Vault-Token: ${SCIM_TOKEN}" \
  "${VAULT_ADDR}/v1/identity/scim/v2/ServiceProviderConfig" 2>/dev/null || echo "000")
check_status "ServiceProviderConfig" "${STATUS}"

USER_COUNT=$(curl -sf \
  -H "X-Vault-Token: ${SCIM_TOKEN}" \
  "${VAULT_ADDR}/v1/identity/scim/v2/Users" 2>/dev/null | jq '.totalResults // 0')
pass "SCIM users provisioned: ${USER_COUNT}"

GROUP_COUNT=$(curl -sf \
  -H "X-Vault-Token: ${SCIM_TOKEN}" \
  "${VAULT_ADDR}/v1/identity/scim/v2/Groups" 2>/dev/null | jq '.totalResults // 0')
pass "SCIM groups provisioned: ${GROUP_COUNT}"

ENTITY_COUNT=$(vault list -format=json identity/entity/name 2>/dev/null | jq 'length // 0')
check_count "Vault entities (root)" "${ENTITY_COUNT}"

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "${FAILED}" -eq 0 ]; then
  echo "All SCIM checks passed ✓"
else
  echo "One or more SCIM checks failed ✗"
  exit 1
fi
