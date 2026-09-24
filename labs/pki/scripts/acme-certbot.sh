#!/bin/bash
# Request a certificate from the Vault PKI ACME endpoint using certbot in a container.
# Usage: acme-certbot.sh [rsa_key_size]   (default 4096; the default role rejects smaller keys)
set -euo pipefail

RSA_KEY_SIZE="${1:-4096}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:?VAULT_NAMESPACE must be set}"
# Address of Vault as seen from inside the docker-vault-stack network
ACME_VAULT_ADDR="${ACME_VAULT_ADDR:-http://vault.localhost:8200}"
CERTBOT_CERT_NAME="${CERTBOT_CERT_NAME:-acme-demo.example.com}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Fresh external account binding (EAB) credentials; the mount requires EAB
eab_json="$(vault write -format=json -f pki/acme/new-eab)"
eab_kid="$(jq -r '.data.id' <<<"$eab_json")"
eab_hmac_key="$(jq -r '.data.key' <<<"$eab_json")"

mkdir -p "$LAB_DIR/acme/etc" "$LAB_DIR/acme/web"

"$CONTAINER_RUNTIME" run --rm \
  --name acme-certbot \
  --network docker-vault-stack \
  -e VAULT_ADDR="$ACME_VAULT_ADDR" \
  -e VAULT_NAMESPACE="$VAULT_NAMESPACE" \
  -e CERTBOT_CERT_NAME="$CERTBOT_CERT_NAME" \
  -e CERTBOT_EAB_KID="$eab_kid" \
  -e CERTBOT_EAB_HMAC_KEY="$eab_hmac_key" \
  -e CERTBOT_RSA_KEY_SIZE="$RSA_KEY_SIZE" \
  -v "$LAB_DIR/acme/web:/var/www/html" \
  -v "$LAB_DIR/acme/etc:/etc/letsencrypt" \
  -v "$LAB_DIR/acme/certbot-entrypoint.sh:/entrypoint.sh:ro" \
  --entrypoint /entrypoint.sh \
  certbot/certbot
