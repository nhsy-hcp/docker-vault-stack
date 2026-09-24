#!/bin/sh
# Runs inside the certbot/certbot image (no bash available), so keep this POSIX sh.
set -eu

VAULT_ADDR="${VAULT_ADDR:-http://vault.localhost:8200}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-admin/tn001}"
CERTBOT_RSA_KEY_SIZE="${CERTBOT_RSA_KEY_SIZE:-4096}"
CERTBOT_CERT_NAME="${CERTBOT_CERT_NAME:-acme-demo.example.com}"
CERTBOT_EAB_KID="${CERTBOT_EAB_KID:?CERTBOT_EAB_KID must be set}"
CERTBOT_EAB_HMAC_KEY="${CERTBOT_EAB_HMAC_KEY:?CERTBOT_EAB_HMAC_KEY must be set}"

ACME_SERVER="${VAULT_ADDR%/}/v1/${VAULT_NAMESPACE}/pki/acme/directory"
echo "Using ACME server: $ACME_SERVER"
echo "Using RSA key size: $CERTBOT_RSA_KEY_SIZE"
echo "Using cert name: $CERTBOT_CERT_NAME"

certbot certonly \
  --non-interactive \
  --agree-tos \
  --register-unsafely-without-email \
  --config-dir /etc/letsencrypt \
  --work-dir /tmp/letsencrypt \
  --logs-dir /tmp/letsencrypt/log \
  --cert-name "$CERTBOT_CERT_NAME" \
  --force-renewal \
  --key-type rsa \
  --rsa-key-size "$CERTBOT_RSA_KEY_SIZE" \
  --server "$ACME_SERVER" \
  --eab-kid "$CERTBOT_EAB_KID" \
  --eab-hmac-key "$CERTBOT_EAB_HMAC_KEY" \
  --webroot -w /var/www/html \
  -d "$CERTBOT_CERT_NAME"

openssl x509 \
  -in "/etc/letsencrypt/live/$CERTBOT_CERT_NAME/cert.pem" \
  -noout -text

echo
cat /tmp/letsencrypt/log/letsencrypt.log
