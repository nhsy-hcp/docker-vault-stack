# Authentik OIDC Integration with HashiCorp Vault

This lab demonstrates how to integrate [Authentik](https://goauthentik.io/) as an OIDC (OpenID Connect) provider for HashiCorp Vault authentication. It showcases multi-namespace authentication, group-based access control, and identity management patterns.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Testing Authentication](#testing-authentication)
- [Understanding the Configuration](#understanding-the-configuration)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Overview

This lab creates:
- **Authentik Stack**: OAuth2/OIDC provider with PostgreSQL backend
- **Vault Namespaces**: Root, admin, and tenant (tn001) namespaces
- **OIDC Authentication**: Configured in root and admin namespaces
- **Identity Groups**: External and internal groups for access control
- **Sample Secrets**: KV secrets for testing access permissions

### Key Features

- ✅ No Redis required (simplified deployment)
- ✅ Multi-namespace authentication
- ✅ Group-based access control
- ✅ Custom OIDC scope mappings
- ✅ Automated setup with Taskfile
- ✅ Complete Terraform automation

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Compose Stack                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │   Authentik      │         │  PostgreSQL      │             │
│  │   (Server)       │◄────────┤  (Database)      │             │
│  │   Port: 9000     │         │  Port: 5432      │             │
│  └──────────────────┘         └──────────────────┘             │
│           │                                                      │
│           │ OIDC                                                │
│           ▼                                                      │
│  ┌──────────────────┐                                          │
│  │   Vault          │                                          │
│  │   (External)     │                                          │
│  │   Port: 8200     │                                          │
│  └──────────────────┘                                          │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Authentication Flow

```
User → Vault UI/CLI → Authentik Login → Group Mapping → Vault Token
```

### Namespace Structure

```
Root (/)
├── OIDC Auth: vault-admin group
└── Admin (/admin)
    ├── OIDC Auth: vault-user group
    └── Tenant (/admin/tn001)
        └── KV Secrets: team1/*
```

## Prerequisites

### Required Software

- Docker and Docker Compose
- Terraform CLI (>= 1.0)
- Vault CLI
- Task runner: `brew install go-task`
- jq: `brew install jq`

### Required Services

- Parent Vault stack must be running: `task up` (from project root)
- Vault must be initialized and unsealed
- Network `docker-vault-stack` must exist

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

**Note:** Vault environment variables (`VAULT_ADDR`, `VAULT_TOKEN`, `VAULT_SKIP_VERIFY`) are inherited from the parent project's `.env` file. You only need to configure Authentik-specific variables.

Generate required secrets:

```bash
# Generate Authentik secret key
openssl rand -base64 32

# Generate bootstrap token
openssl rand -hex 32

# Generate PostgreSQL password
openssl rand -base64 24
```

## Quick Start

### One-Command Setup

From the project root:

```bash
# 1. Start all services (including Authentik)
task up

# 2. Run complete Authentik setup
task authentik:all
```

This will:
1. Create admin user and generate API token
2. Initialize Terraform
3. Apply the Vault OIDC configuration

### Manual Setup

If you prefer step-by-step setup:

```bash
# 1. Start all services (including Authentik)
task up

# 2. Wait for Authentik to be ready
# The setup script will wait automatically

# 3. Run setup script to create admin and generate token
cd labs/authentik
./setup-admin.sh

# 4. Initialize Terraform
task authentik:init

# 5. Apply Terraform configuration
task authentik:apply
```

## Detailed Setup

### Step 1: Configure Environment

Edit `.env` file with your values:

```bash
# Authentik Configuration
AUTHENTIK_SECRET_KEY=<your-generated-key>
AUTHENTIK_BOOTSTRAP_PASSWORD=admin
AUTHENTIK_BOOTSTRAP_TOKEN=<your-generated-token>
AUTHENTIK_POSTGRESQL_PASSWORD=<your-generated-password>

# Authentik Provider Configuration (used by Terraform)
AUTHENTIK_URL=http://localhost:9000
AUTHENTIK_TOKEN=<from-authentik-ui>

# Docker Compose
COMPOSE_PROJECT_NAME=docker-vault-stack
```

**Note:** Vault configuration (`VAULT_ADDR`, `VAULT_TOKEN`, `VAULT_SKIP_VERIFY`) is inherited from the parent project's `.env` file.

### Step 2: Start Services

From project root, start all services (including Authentik):

```bash
task up
```

Verify Authentik services are running:

```bash
task authentik:status
```

Check health:

```bash
task authentik:health
```

### Step 3: Generate Authentik API Token

1. Access Authentik UI: http://localhost:9000
2. Login with admin credentials (from `AUTHENTIK_BOOTSTRAP_PASSWORD`)
3. Navigate to: **Admin Interface** → **Tokens** → **Create Token**
4. Create a token with:
   - **User**: akadmin
   - **Intent**: API
   - **Expiring**: No (or set expiration as needed)
5. Copy the token value
6. Add to `.env` as `AUTHENTIK_TOKEN`

### Step 4: Deploy with Terraform

```bash
# Initialize Terraform
task authentik:init

# Review the plan
task authentik:plan

# Apply the configuration
task authentik:apply
```

### Step 5: Verify Deployment

```bash
# Check Terraform outputs
terraform output

# Verify OIDC configuration
curl -k http://localhost:9000/application/o/vault/.well-known/openid-configuration | jq

# Check Vault namespaces
vault namespace list
vault namespace list -namespace=admin
```

## Testing Authentication

### Test 1: Root Namespace (Admin Access)

Login as `vaultadmin` (member of `vault-admin` group):

```bash
# CLI login
vault login -method=oidc role=default

# Or use the demo script
./demo-auth.sh
```

Verify admin access:

```bash
# Should have full access
vault namespace list
vault policy list
vault auth list
```

### Test 2: Admin Namespace (User Access)

Login as `testuser1` (member of `vault-user` group):

```bash
# CLI login
vault login -namespace=admin -method=oidc role=default
```

Verify user access:

```bash
# Should have limited access
vault namespace list -namespace=admin
vault kv list -namespace=admin/tn001 team1
```

### Test 3: Read Secrets (Team Reader)

As `testuser1` (member of `vault-tn001-team1-reader` group):

```bash
# Read secrets
vault kv get -namespace=admin/tn001 team1/app1
vault kv get -namespace=admin/tn001 team1/app2
```

### Test 4: Verify Group Membership

```bash
# Check current token
vault token lookup

# Get entity ID
ENTITY_ID=$(vault token lookup -format=json | jq -r '.data.entity_id')

# View entity details
vault read identity/entity/id/$ENTITY_ID

# Or use the helper script
./check-policies.sh
```

## Understanding the Configuration

### Authentik Groups

Three groups are created with different access levels:

| Group | Description | Vault Access |
|-------|-------------|--------------|
| `vault-admin` | Full administrators | Root namespace, all permissions |
| `vault-user` | Standard users | Admin namespace, default access |
| `vault-tn001-team1-reader` | Team readers | Tenant namespace, read-only to team1/* |

### Vault Namespaces

```
/ (root)
├── OIDC mount: /oidc
├── Policy: authentik-admin
└── admin/
    ├── OIDC mount: /oidc
    └── tn001/
        ├── KV mount: team1/
        ├── Policy: authentik-tn001-team1-reader
        └── Secrets: app1, app2
```

### Identity Groups

**External Groups** (linked to Authentik):
- `authentik-vault-admin-external` → `vault-admin` group
- `authentik-vault-tn001-team1-reader-external` → `vault-tn001-team1-reader` group

**Internal Groups** (Vault-managed):
- `authentik-vault-tn001-team1-reader-internal` → Inherits from external group

### OIDC Configuration

**Scopes**: `openid`, `profile`, `email`, `groups`

**Claims**:
- `user_claim`: `email` (user identifier)
- `groups_claim`: `groups` (group membership)

**Redirect URIs**:
- `http://localhost:8250/oidc/callback` (CLI)
- `https://127.0.0.1:8200/ui/vault/auth/oidc/oidc/callback` (UI)
- `https://localhost:8200/ui/vault/auth/oidc/oidc/callback` (UI alternate)

## Troubleshooting

### Authentik Not Starting

```bash
# Check logs
task authentik:logs

# Check specific service
task authentik:logs-server
task authentik:logs-postgres

# Restart services
task authentik:restart
```

### OIDC Discovery URL Not Accessible

```bash
# Verify Authentik is running
curl -k http://localhost:9000/-/health/live/

# Check OIDC configuration
curl -k http://localhost:9000/application/o/vault/.well-known/openid-configuration
```

### Authentication Fails

```bash
# Verify OIDC mount exists
vault auth list
vault auth list -namespace=admin

# Check OIDC configuration
vault read auth/oidc/config
vault read -namespace=admin auth/oidc/config

# Verify group membership in Authentik UI
# Admin Interface > Directory > Groups
```

### Group Mapping Not Working

```bash
# Check identity groups
vault list identity/group/name
vault list -namespace=admin identity/group/name

# Check group aliases
vault list identity/group-alias/id

# Verify entity after login
ENTITY_ID=$(vault token lookup -format=json | jq -r '.data.entity_id')
vault read identity/entity/id/$ENTITY_ID
```

### Terraform Errors

```bash
# Refresh state
terraform refresh

# Check for drift
terraform plan

# Re-apply if needed
terraform apply
```

### Network Issues

```bash
# Verify network exists
docker network ls | grep docker-vault-stack

# Check if services are on the same network
docker network inspect docker-vault-stack
```

## Available Tasks

From the project root, use `task authentik:<command>`:

| Command | Description |
|---------|-------------|
| `all` | Complete setup workflow (up + init + apply) |
| `up` | Start Authentik stack |
| `down` | Stop Authentik stack |
| `restart` | Restart Authentik stack |
| `status` | Show status of all services |
| `health` | Check health of all services |
| `logs` | View logs from all services |
| `logs-server` | View Authentik server logs |
| `logs-worker` | View Authentik worker logs |
| `logs-postgres` | View PostgreSQL logs |
| `init` | Initialize Terraform |
| `plan` | Run Terraform plan |
| `apply` | Apply Terraform configuration |
| `destroy` | Destroy Terraform resources |
| `test-auth` | Test OIDC authentication |
| `check-policies` | Check current token policies |
| `bootstrap` | Complete setup from scratch |
| `clean` | Remove all containers and volumes |

## Cleanup

### Remove Terraform Resources

```bash
task authentik:destroy
```

### Stop Services

Stop all services (including Authentik) from project root:

```bash
task down
```

### Redeploy Authentik (Clean Slate)

To stop Authentik services, remove volumes, and restart:

```bash
task authentik:redeploy
```

This will prompt for confirmation before deleting all Authentik data and restarting services.

## Additional Resources

- [Authentik Documentation](https://docs.goauthentik.io/)
- [Authentik-Vault Integration Guide](https://integrations.goauthentik.io/security/hashicorp-vault/)
- [Vault OIDC Auth Method](https://developer.hashicorp.com/vault/docs/auth/jwt)
- [Authentik Terraform Provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)

## Notes

- This lab uses Authentik without Redis for simplified deployment
- All services communicate over the parent project's Docker network
- TLS verification is disabled for local development (not for production)
- Default passwords should be changed for production use
- API tokens should be rotated regularly

## License

This lab is part of the docker-vault-stack training environment.
