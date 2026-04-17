#!/bin/bash
set -euo pipefail

# Load environment variables from main .env file
if [ -f ../../.env ]; then
    set -a
    source ../../.env
    set +a
elif [ -f .env ]; then
    # Fallback to local .env if main doesn't exist
    set -a
    source .env
    set +a
fi

echo "=== Authentik Admin Setup Automation ==="
echo ""

# Configuration
ADMIN_USER="${AUTHENTIK_ADMIN_USER:-akadmin}"
NEW_PASSWORD="${AUTHENTIK_ADMIN_PASSWORD:?AUTHENTIK_ADMIN_PASSWORD must be set in .env file}"
AUTHENTIK_URL="http://localhost:9000"

# Generate AUTHENTIK_SECRET_KEY if not set or is placeholder
if [ -z "${AUTHENTIK_SECRET_KEY:-}" ] || [ "${AUTHENTIK_SECRET_KEY}" = "CHANGE_ME_GENERATE_RANDOM_KEY" ]; then
    echo "Generating AUTHENTIK_SECRET_KEY..."
    AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
    echo "✅ Generated new AUTHENTIK_SECRET_KEY"

    # Update .env file with generated secret key
    ENV_FILE="../../.env"
    if [ -f "$ENV_FILE" ]; then
        if grep -q "^AUTHENTIK_SECRET_KEY=" "$ENV_FILE"; then
            sed -i '' "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}|" "$ENV_FILE"
        else
            echo "AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}" >> "$ENV_FILE"
        fi
        echo "✅ Updated .env with AUTHENTIK_SECRET_KEY"
    fi
    echo ""
fi

# Wait for Authentik to be ready (HTTP 200)
echo "Waiting for Authentik to be ready..."
MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${AUTHENTIK_URL}/-/health/live/ 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Authentik is ready! (HTTP 200)"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    if [ $((ATTEMPT % 10)) -eq 0 ]; then
        echo "Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting... (HTTP $HTTP_CODE)"
    fi
    sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "❌ Authentik did not become ready in time (last HTTP code: $HTTP_CODE)"
    exit 1
fi

echo ""
echo "Step 1: Setting admin password and creating API token via Python..."

# Create temporary Python script
cat > /tmp/authentik_setup.py << EOFPYTHON
import os
import django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "authentik.root.settings")
django.setup()

from django.contrib.auth import get_user_model
from authentik.core.models import Token, TokenIntents

User = get_user_model()

username = "${ADMIN_USER}"
password = "${NEW_PASSWORD}"

try:
    # Get or create user
    user, created = User.objects.get_or_create(
        username=username,
        defaults={
            "name": username,
            "is_active": True,
            "email": f"{username}@example.com",
            "path": username,
            "type": "internal",
        }
    )

    if created:
        print(f"USER_CREATED:{username}")
        # Make user superuser by adding to admins group
        from authentik.core.models import Group
        admin_group, _ = Group.objects.get_or_create(
            name="authentik Admins",
            defaults={"is_superuser": True}
        )
        user.ak_groups.add(admin_group)

    # Set password
    user.set_password(password)
    user.save()
    print(f"PASSWORD_SET:{username}")

    # Delete existing token if it exists
    Token.objects.filter(identifier="terraform-token").delete()

    # Create new API token
    token = Token.objects.create(
        identifier="terraform-token",
        user=user,
        intent=TokenIntents.INTENT_API,
        description="Terraform API Token",
        expiring=False,
    )

    print(f"TOKEN:{token.key}")

except Exception as e:
    import traceback
    print(f"ERROR:{str(e)}")
    traceback.print_exc()
    exit(1)
EOFPYTHON

# Execute Python script in container
RESULT=$(docker compose -f ../../docker-compose.yml exec -T authentik-server python < /tmp/authentik_setup.py 2>&1)

# Clean up temp file
rm -f /tmp/authentik_setup.py

# Parse the result
if echo "$RESULT" | grep -q "ERROR:"; then
    echo "❌ Failed to setup admin"
    echo "$RESULT"
    exit 1
fi

if echo "$RESULT" | grep -q "USER_CREATED:"; then
    USER_CREATED=$(echo "$RESULT" | grep "USER_CREATED:" | cut -d: -f2)
    echo "✅ User created: ${USER_CREATED}"
fi

PASSWORD_STATUS=$(echo "$RESULT" | grep "PASSWORD_SET:" | cut -d: -f2)
API_TOKEN=$(echo "$RESULT" | grep "TOKEN:" | cut -d: -f2)

if [ -z "$API_TOKEN" ]; then
    echo "❌ Failed to generate API token"
    echo "$RESULT"
    exit 1
fi

echo "✅ Password set for ${PASSWORD_STATUS}"
echo "✅ API token generated"

# Update .env file
echo ""
echo "Step 2: Updating .env file..."

if [ -f .env ]; then
    # Update or add AUTHENTIK_TOKEN
    if grep -q "^export AUTHENTIK_TOKEN=" .env || grep -q "^AUTHENTIK_TOKEN=" .env; then
        sed -i '' "s|^export AUTHENTIK_TOKEN=.*|export AUTHENTIK_TOKEN=${API_TOKEN}|" .env
        sed -i '' "s|^AUTHENTIK_TOKEN=.*|export AUTHENTIK_TOKEN=${API_TOKEN}|" .env
    else
        echo "export AUTHENTIK_TOKEN=${API_TOKEN}" >> .env
    fi

    # Update or add AUTHENTIK_ADMIN_PASSWORD
    if grep -q "^AUTHENTIK_ADMIN_PASSWORD=" .env; then
        sed -i '' "s|^AUTHENTIK_ADMIN_PASSWORD=.*|AUTHENTIK_ADMIN_PASSWORD=${NEW_PASSWORD}|" .env
    else
        echo "AUTHENTIK_ADMIN_PASSWORD=${NEW_PASSWORD}" >> .env
    fi

    # Update or add AUTHENTIK_ADMIN_USER
    if grep -q "^AUTHENTIK_ADMIN_USER=" .env; then
        sed -i '' "s|^AUTHENTIK_ADMIN_USER=.*|AUTHENTIK_ADMIN_USER=${ADMIN_USER}|" .env
    else
        echo "AUTHENTIK_ADMIN_USER=${ADMIN_USER}" >> .env
    fi

    echo "✅ Updated .env file"
else
    echo "export AUTHENTIK_TOKEN=${API_TOKEN}" > .env
    echo "AUTHENTIK_ADMIN_PASSWORD=${NEW_PASSWORD}" >> .env
    echo "AUTHENTIK_ADMIN_USER=${ADMIN_USER}" >> .env
    echo "✅ Created .env file"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Admin Credentials:"
echo "  Username: ${ADMIN_USER}"
echo "  Password: ${NEW_PASSWORD}"
echo "  Login URL: ${AUTHENTIK_URL}"
echo ""
echo "API Token: ${API_TOKEN}"
echo ""
