#!/bin/bash
# Smoke test for the PKI lab: issuance per role, chain validation, role
# restrictions, CSR signing, CRL, templated AIA URLs and the ACME directory.
set -euo pipefail

VAULT_NAMESPACE="${VAULT_NAMESPACE:?VAULT_NAMESPACE must be set}"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$LAB_DIR/.tmp/test"
PKI_URL="${VAULT_ADDR%/}/v1/$VAULT_NAMESPACE/pki"
failures=0

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }

mkdir -p "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

# Vault backdates leaf NotBefore by 30s, so a freshly deployed intermediate
# rejects issuance ("notBefore before signer's notBefore") for its first ~30s.
for _ in $(seq 1 20); do
  vault write -field=certificate pki/issue/default common_name=ready.example.com ttl=1m >/dev/null 2>&1 && break
  sleep 3
done

# Issue a short-lived cert per role and verify it chains to the local root CA
for role in default v1 v2; do
  issuer_var="v1"
  [[ "$role" == "v2" ]] && issuer_var="v2"
  crt="$WORK_DIR/$role.crt"
  if vault write -field=certificate "pki/issue/$role" common_name="test.example.com" ttl=5m >"$crt" &&
    openssl verify -CAfile "$LAB_DIR/certs/root-ca.pem" \
      -untrusted "$LAB_DIR/certs/intermediate-$issuer_var.pem" "$crt" >/dev/null; then
    pass "role $role issues a cert chaining to intermediate $issuer_var"
  else
    fail "role $role issuance or chain verification"
  fi
done

# Templated AIA/CRL URLs must include the namespace path
if openssl x509 -in "$WORK_DIR/default.crt" -noout -text | grep -q "$VAULT_NAMESPACE/pki/issuer/"; then
  pass "AIA/CRL URLs include namespace path"
else
  fail "AIA/CRL URLs missing namespace path"
fi

# Role restrictions: v2 rejects localhost, default allows it
if vault write -field=certificate pki/issue/v2 common_name=localhost ttl=5m >/dev/null 2>&1; then
  fail "role v2 should reject localhost"
else
  pass "role v2 rejects localhost"
fi
if vault write -field=certificate pki/issue/default common_name=localhost ttl=5m >/dev/null 2>&1; then
  pass "role default allows localhost"
else
  fail "role default should allow localhost"
fi

# Out-of-domain names are rejected
if vault write -field=certificate pki/issue/default common_name=test.other.org ttl=5m >/dev/null 2>&1; then
  fail "role default should reject test.other.org"
else
  pass "role default rejects out-of-domain names"
fi

# Sign an externally generated CSR
openssl req -new -newkey rsa:4096 -nodes -keyout "$WORK_DIR/sign.key" \
  -out "$WORK_DIR/sign.csr" -subj "/CN=sign.example.com" 2>/dev/null
if vault write -field=certificate pki/sign/default csr=@"$WORK_DIR/sign.csr" ttl=5m >"$WORK_DIR/sign.crt" &&
  openssl x509 -in "$WORK_DIR/sign.crt" -noout -subject | grep -q "sign.example.com"; then
  pass "CSR signed via pki/sign/default"
else
  fail "CSR signing"
fi

# CRL is served and parseable
if curl -sf "$PKI_URL/crl" | openssl crl -inform DER -noout 2>/dev/null ||
  curl -sf "$PKI_URL/crl/pem" | openssl crl -noout 2>/dev/null; then
  pass "CRL served at $PKI_URL/crl"
else
  fail "CRL not served"
fi

# ACME directory is enabled
if curl -sf "$PKI_URL/acme/directory" | jq -e '.newAccount' >/dev/null; then
  pass "ACME directory available"
else
  fail "ACME directory not available"
fi

echo
if ((failures > 0)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All checks passed"
