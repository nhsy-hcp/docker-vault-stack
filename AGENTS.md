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
- Authentik as OIDC provider (no Redis required)
- Multi-namespace OIDC authentication (root and admin)
- Automated admin user creation and API token generation
- Group-based access control with external identity groups
- Complete Terraform automation

**Lab Commands:**
```bash
# From project root - start all services
task up

# Run complete Authentik setup
task authentik:all

# Test OIDC authentication
task authentik:test-auth

# Redeploy with fresh data
task authentik:redeploy
```

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
- UI access: http://localhost:8200 (Vault), http://localhost:3000 (Grafana)

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
