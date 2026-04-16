#!/bin/bash
set -euo pipefail

echo "=== Authentik API Token Generator ==="
echo ""

# Wait for Authentik to be ready
echo "Waiting for Authentik to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -sf http://localhost:9000/-/health/live/ > /dev/null 2>&1; then
        echo "✅ Authentik is ready!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting..."
    sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "❌ Authentik did not become ready in time"
    exit 1
fi

echo ""
echo "Generating API token..."
echo ""

# Generate token via API
RESPONSE=$(curl -s -X POST http://localhost:9000/api/v3/core/tokens/ \
  -H "Content-Type: application/json" \
  -u "akadmin:${AUTHENTIK_BOOTSTRAP_PASSWORD:-admin}" \
  -d '{
    "identifier": "terraform-token",
    "intent": "api",
    "description": "Terraform API Token"
  }' 2>&1)

# Extract token from response
TOKEN=$(echo "$RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to generate token"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "✅ Token generated successfully!"
echo ""
echo "Token: $TOKEN"
echo ""

# Update .env file
if [ -f .env ]; then
    # Check if AUTHENTIK_TOKEN exists
    if grep -q "^export AUTHENTIK_TOKEN=" .env || grep -q "^AUTHENTIK_TOKEN=" .env; then
        # Replace existing value
        sed -i.bak "s|^export AUTHENTIK_TOKEN=.*|export AUTHENTIK_TOKEN=$TOKEN|" .env
        sed -i.bak "s|^AUTHENTIK_TOKEN=.*|export AUTHENTIK_TOKEN=$TOKEN|" .env
        rm -f .env.bak
        echo "✅ Updated AUTHENTIK_TOKEN in .env file"
    else
        # Add new line
        echo "export AUTHENTIK_TOKEN=$TOKEN" >> .env
        echo "✅ Added AUTHENTIK_TOKEN to .env file"
    fi
else
    echo "⚠️  .env file not found, creating it..."
    echo "export AUTHENTIK_TOKEN=$TOKEN" > .env
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "You can now run:"
echo "  task authentik:init"
echo "  task authentik:apply"
echo ""
