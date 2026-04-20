# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a HashiCorp Vault training environment that provides a complete Docker Compose stack with Vault Enterprise, monitoring tools (Grafana, Prometheus, Loki), and various lab exercises. The repository is structured as a learning platform for Vault features like namespaces, ACL templating, and identity management.

## Architecture

### Stack Components
- **Vault Enterprise**: Main service with Raft storage backend and audit logging enabled
- **Monitoring Stack**: Grafana (dashboards), Prometheus (metrics), Loki (log aggregation), Alloy (metrics collection)
- **Training Labs**: Located in `/labs/` with specific Vault feature demonstrations

### Key Configuration Files
- `docker-compose.yml`: Complete stack definition with Vault Enterprise and monitoring
- `volumes/vault/raft.hcl`: Vault server configuration with Raft backend (HTTP mode)
- `volumes/alloy/config.alloy`: Alloy configuration for metrics collection
- `.env`: Environment variables for VAULT_ADDR, VAULT_LICENSE, VAULT_TOKEN
- `Taskfile.yml`: Task runner with all operational commands

## Essential Commands

### Stack Management
```bash
# Start the complete stack
task up

# Initialize Vault (first time only)
task init

# Initialize Vault without prompt (auto-approve)
task init --yes

# Unseal Vault after restart
task unseal

# View status
task status
vault status

# Open UIs in browser and display URLs
task ui

# Clean shutdown
task down

# Complete cleanup (removes volumes)
task clean
```

### Available Tasks (Root)
```bash
task --list
```

**Key Tasks:**
- `lint` - Run pre-commit hooks on all files
- `tokens` - List all token accessors with details
- `authentik:all` - Complete Authentik OIDC setup workflow
- `authentik:redeploy` - Stop, remove volumes, and restart Authentik
- `authentik:logs` - View Authentik logs
- `authentik:status` - Show Authentik service status

### Environment Setup
```bash
# Required environment file (.env)
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_LICENSE=INSERT_LICENSE_HERE
export VAULT_TOKEN=<from_vault_init>

# Load environment
source .env
```

### Vault Operations
```bash
# Run performance benchmark (requires vault-benchmark CLI)
vault namespace create vault-benchmark
task benchmark

# Access Vault metrics
task metrics

# Backup Raft snapshot
task backup

# View logs
task logs-vault
task logs
```

## Lab Structure

### `/labs/acl-templating/`
Demonstrates ACL templating with AppRole authentication across multiple namespaces (bu01, bu02, bu03).

**Key Features:**
- Uses `vault_policy_document` data source for policy templates
- Centralized configuration via Terraform locals
- Dynamic policy generation using `{{identity.entity.aliases.<accessor>.metadata.team}}`
- Consolidated outputs for role IDs and secret IDs

**Lab Commands:**
```bash
cd labs/acl-templating
terraform init && terraform apply
./secrets.sh  # Creates test secrets

# Get credentials
export ROLE_ID=$(terraform output -json app_role_ids | jq -r '.bu01')
export SECRET_ID=$(terraform output -json app_secret_ids | jq -r '.bu01')
```

### `/labs/namespaces/`
Demonstrates namespace management, KV secrets engine, and identity groups.

**Key Features:**
- Nested namespaces (admin/bu0001, admin/bu0002, admin/bu0003, admin/shared)
- Userpass authentication in admin namespace
- Identity groups with team-based access policies

### `/labs/authentik/`
Demonstrates Authentik OIDC integration with Vault for multi-namespace authentication.

**Key Features:**
- Authentik 2026.2.2 as OIDC provider (no Redis required)
- Multi-namespace OIDC authentication (root and admin namespaces)
- Automated admin user creation and API token generation
- Group-based access control with external identity groups
- Complete Terraform automation with user and policy management
- Network-aware configuration (separate URLs for Terraform provider vs Vault OIDC)

**Architecture:**
- **Authentik Server**: OIDC provider (port 9000)
- **PostgreSQL**: Database backend (internal)
- **Authentik Worker**: Background task processor
- **Vault**: OIDC client (configured via Terraform)

**Critical Network Configuration:**
- Terraform provider uses `http://localhost:9000` (host access)
- Vault OIDC uses `http://authentik.localhost:9000` (Docker network alias / service hostname)
- Both services communicate on `docker-vault-stack` network

**Lab Commands:**
```bash
# From project root - start all services
task up

# Run complete Authentik setup (automated end-to-end)
task authentik:all

# Step-by-step setup
cd labs/authentik
./setup-admin.sh              # Create admin user and generate API token
task authentik:init           # Initialize Terraform
task authentik:plan           # Review planned changes
task authentik:apply          # Apply Terraform configuration

# Testing and verification
task authentik:test-auth      # Test OIDC authentication flow
task authentik:check-policies # Verify token policies

# Service management
task authentik:status         # Check container status
task authentik:health         # Health checks
task authentik:logs           # View all service logs
task authentik:restart        # Restart Authentik services
task authentik:redeploy       # Clean slate deployment (removes volumes)

# Cleanup
task authentik:purge          # Remove Terraform state and disable Vault OIDC auth
```

**Environment Requirements:**
The lab requires specific environment variables in `.env`:
- `AUTHENTIK_SECRET_KEY` - Generate with `openssl rand -base64 32`
- `AUTHENTIK_ADMIN_USER` - Admin username (default: akadmin)
- `AUTHENTIK_ADMIN_PASSWORD` - **REQUIRED** - Admin password (no default)
- `AUTHENTIK_TOKEN` - Auto-generated by `setup-admin.sh`
- `PG_PASS` - PostgreSQL password
- `AUTHENTIK_URL` - `http://localhost:9000` (for Terraform provider)

**Setup Script (`setup-admin.sh`):**
1. Waits for Authentik to be ready (HTTP 200)
2. Creates/updates admin user with password from `.env`
3. Generates API token with admin permissions
4. Updates `.env` with `AUTHENTIK_TOKEN`

**Important Notes:**
- `AUTHENTIK_ADMIN_PASSWORD` must be set in `.env` before running setup
- `AUTHENTIK_BOOTSTRAP_PASSWORD` only works on first-time database initialization
- If OIDC auth backends exist in Vault, disable them first before applying
- All bash scripts pass shellcheck validation

**Troubleshooting:**
- Check logs: `task authentik:logs-server`, `task authentik:logs-postgres`
- Verify environment: Ensure `.env` contains all required variables
- Network issues: Verify Docker network `docker-vault-stack` exists
- Clean restart: `task authentik:redeploy` for fresh deployment

**References:**
- Detailed lab documentation: `labs/authentik/AGENTS.md`
- [Authentik Documentation](https://docs.goauthentik.io/)
- [Vault OIDC Auth Method](https://developer.hashicorp.com/vault/docs/auth/oidc)

## Working with Labs

### Terraform Patterns
When working with Vault labs, follow these patterns:

1. **Configuration Structure:**
   ```hcl
   locals {
     business_units = {
       bu01 = { namespace = "bu01", team = "team1" }
       # ... more units
     }

     shared_config = {
       # Common settings
     }
   }
   ```

2. **Policy Templates:**
   Use `data "vault_policy_document"` with structured rules instead of inline HCL strings.

3. **Outputs:**
   Prefer map-based outputs over individual outputs:
   ```hcl
   output "resource_ids" {
     value = {
       for k, v in vault_resource.instances : k => v.id
     }
   }
   ```

### Vault Authentication Testing
```bash
# AppRole authentication example
export VAULT_TOKEN=$(vault write -namespace=bu01 -field=token auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID")

# Test access
vault kv get -namespace=bu01 team1/app1
```

## Development Workflow

### Prerequisites
- Docker and Docker Compose
- Task runner: `brew install go-task jq`
- Terraform CLI
- Vault CLI
- Valid Vault Enterprise license (or modify docker-compose.yml for OSS)

### Typical Workflow
1. `task up` - Start stack
2. `task init` - Initialize Vault (first time)
3. `task unseal` - Unseal Vault
4. `source .env` - Load environment
5. Work in lab directories with `terraform init/plan/apply`
6. `task clean` - Full cleanup when done

### Debugging
- Vault logs: `task logs-vault`
- All services: `task logs`
- Vault status: `vault status`
- UI access: http://vault.localhost:8200 (Vault), http://grafana.localhost:3000 (Grafana)

## Important Notes

### Security Considerations
- The `.env` file contains sensitive tokens - never commit this
- Default setup uses Vault Enterprise - ensure license compliance
- All services expose ports locally - not for production use
- TLS is disabled by default for easier deployment
- This is a training environment - production deployments should use TLS

### State Management
- Terraform state files are created in lab directories
- `vault-init.json` contains unseal keys and root token
- Docker volumes persist data between restarts

### Resource Naming
When creating resources in labs, use consistent naming patterns:
- Providers: `vault.{namespace}` aliases
- Resources: Include namespace/bu identifier in name
- Outputs: Use descriptive names with map structures
