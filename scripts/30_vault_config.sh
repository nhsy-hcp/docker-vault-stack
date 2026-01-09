#!/bin/bash

# 30_vault_config.sh - Configure Vault for monitoring and integrations
# This script should be run after Vault is initialized and unsealed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Removed prometheus-metrics token to simplify
#print_status "Configuring Vault for Prometheus metrics collection..."
#
## Create prometheus metrics policy
#print_status "Creating prometheus-metrics policy..."
#vault policy write prometheus-metrics - << EOF
#path "sys/metrics" {
#  capabilities = ["read"]
#}
#
#path "sys/internal/counters/activity" {
#  capabilities = ["read"]
#}
#EOF
#
## Generate token for Prometheus and save to file
#print_status "Generating token for Prometheus..."
#TOKEN_FILE="./volumes/prometheus/prometheus-token"
#
## Ensure the directory exists
#mkdir -p "$(dirname "$TOKEN_FILE")"

## Create token with prometheus-metrics policy
#vault token create \
#  -display-name="Prometheus Metrics Token" \
#  -field=token \
#  -policy prometheus-metrics \
#  -renewable=true \
#  -period=30d \
#  -metadata=purpose=prometheus \
#  -metadata=owner=nhsy \
#  -orphan=true \
#  > "$TOKEN_FILE"
#
## Set appropriate permissions on token file
#chmod 600 "$TOKEN_FILE"
#print_status "Token file permissions set to 600"
#print_status "Vault configuration for Prometheus completed successfully!"

vault audit enable -path="audit_log" file file_path=/vault/logs/vault_audit.log chmod=0644 || true
vault audit enable -path="audit_stdout" file file_path=stdout || true
vault audit list -detailed
echo ""
vault write sys/quotas/config enable_rate_limit_audit_logging=true
print_status "Vault initialised, unsealed and audit logs enabled"

print_status "Setting vault token TTL..."
vault write sys/auth/token/tune max_lease_ttl=720h #30d
vault write sys/auth/token/tune default_lease_ttl=168h #7d
print_status "Vault token TTL set to 30 days for max and 7 days for default"

vault read sys/auth/token/tune