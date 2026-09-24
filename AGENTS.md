# AGENTS.md

This file provides guidance to AI coding tools when working with code in this repository.

## Repository Overview

This is a HashiCorp Vault training environment that provides a Compose stack (Podman by default, Docker supported) with Vault Enterprise, monitoring tools (Grafana, Prometheus, Loki), and various lab exercises. The repository is structured as a learning platform for Vault features like namespaces, ACL templating, and identity management.

## Architecture

### Stack Components
- **Vault Enterprise**: Main service with Raft storage backend and audit logging enabled
- **Monitoring Stack**: Grafana (dashboards), Prometheus (metrics), Loki (log aggregation), Alloy (metrics collection)
- **Training Labs**: Located in `/labs/` with specific Vault feature demonstrations

### Key Configuration Files
- `compose.yaml`: Complete stack definition with Vault Enterprise and monitoring
- `volumes/vault/raft.hcl`: Vault server configuration with Raft backend (HTTP mode)
- `volumes/alloy/config.alloy`: Alloy configuration for metrics collection and shipping the Vault audit log to Loki
- `volumes/grafana/datasources.yml`, `volumes/grafana/dashboards.yml`: Grafana provisioning. Prometheus `timeInterval` is `60s` to match Alloy's Vault scrape interval; bump a data source's `version` when changing it, because Grafana skips the file if its stored version is higher
- `volumes/grafana/dashboards/*.json`: provisioned dashboards. Keep tags as `["vault", <area>, <datasource>]` and the shared `Vault dashboards` link (a dropdown of all dashboards tagged `vault`)
- `.env`: Environment variables for VAULT_ADDR, VAULT_LICENSE, VAULT_TOKEN (template: `.env.example`)
- `Taskfile.yml`: Task runner with all operational commands

## Essential Commands

### Stack Management
```bash
# Start the complete stack
task up

# Initialize Vault (first time only)
task init

# Re-initialize without the confirmation prompt (args after -- go to the init script)
task init -- --yes

# Unseal Vault after restart
task unseal

# View status
task status
vault status

# Open UIs in browser and display URLs
task ui

# Configure audit devices and token TTLs (after init/unseal)
task config

# Stop containers, keep data
task stop

# Remove containers and volumes, including Vault data (down and clean are aliases; prompts, --yes skips)
task down
```

### Available Tasks (Root)
```bash
task --list
```

**Key Tasks:**
- `lint` - Run pre-commit hooks on all files
- `namespaces` - Create base lab namespaces `admin` and `admin/tn001` (idempotent, not run by `init`; override with `NAMESPACES="..."`)
- `backup` - Save a Raft snapshot plus `vault-init-<timestamp>.json` to `.backups/` (git-ignored; `BACKUP_DIR` var). Restoring a snapshot onto a re-initialised cluster needs `-force` and the matching unseal keys
- `tokens` - List all token accessors with details
- `seed` (alias `vault:seed`) - Run `scripts/seed_vault.py` via `uv` (inline PEP 723 deps: hvac, requests). Creates its own namespace tree `tn001`-`tn010` at the root (independent of `task namespaces`) and seeds each child/grandchild; idempotent (PKI root issuer only created once)
- `authentik:all` - Complete Authentik OIDC setup workflow
- `authentik:redeploy` - Stop, remove volumes, and restart Authentik
- `authentik:logs` - View Authentik logs
- `authentik:status` - Show Authentik service status

### Environment Setup
Copy `.env.example` to `.env` and set `VAULT_LICENSE`; `task init` writes `VAULT_TOKEN`. The root Taskfile loads `.env` for every task (including included labs).

```bash
# Key variables in .env
export VAULT_ADDR=http://vault.localhost:8200   # from .env.example
export VAULT_LICENSE=<license>
export VAULT_TOKEN=<written by task init>

# Load environment for direct CLI use
source .env
```

`vault-benchmark` (v0.3.0, Go 1.19) cannot resolve `*.localhost` names; run `task benchmark` with `VAULT_ADDR=http://127.0.0.1:8200`.

### Vault Operations
```bash
# Run performance benchmark (requires vault-benchmark CLI; creates the vault-benchmark namespace)
VAULT_ADDR=http://127.0.0.1:8200 task benchmark

# Access Vault metrics
task metrics

# Backup Raft snapshot
task backup

# View logs
task logs-vault
task logs
```

## Lab Structure

### Lab Index
Each tracked lab has its own README with the standard layout (Overview, Prerequisites, Quick Start, Usage, Configuration, Available Tasks, Troubleshooting, Cleanup, References). The root README links the same list.

| Lab | Runs from | README |
|-----|-----------|--------|
| ACL Templating | `labs/acl-templating` (terraform) | `labs/acl-templating/README.md` |
| Audit Logs | `labs/audit-logs` (terraform) | `labs/audit-logs/README.md` |
| Authentik (optional) | repo root, `task authentik:*` | `labs/authentik/README.md`, `labs/authentik/AGENTS.md` |
| AWS Secrets Sync | `labs/aws-secrets-sync` (`task`) | `labs/aws-secrets-sync/README.md` |
| Dex (optional) | repo root, `task dex:*` | `labs/dex/README.md` |
| Entra ID | `labs/entra-id` (terraform) | `labs/entra-id/README.md` |
| PKI | repo root, `task pki:*` | `labs/pki/README.md`, `labs/pki/acme-demo.md` |

Other directories under `labs/` are untracked work in progress.

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

### `/labs/authentik/`
Demonstrates Authentik OIDC integration with Vault for multi-namespace authentication.

**Key Features:**
- Authentik 2026.8.3 as OIDC provider (no Redis required)
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

**Optional lab:** Authentik is not part of the core stack. Its services live in `labs/authentik/compose.yaml` and join the root stack's `docker-vault-stack` network (external). Start the core stack first, then `task authentik:up`.

**Critical Network Configuration:**
- Terraform provider uses `http://authentik.localhost:9000` (via Docker network alias)
- Vault OIDC uses `http://authentik.localhost:9000` (Docker network alias / service hostname)
- Both services communicate on `docker-vault-stack` network

**Lab Commands (from repo root):**
```bash
task up
task authentik:all            # up + setup-admin.sh + terraform init + apply

# Step by step
task authentik:up
(cd labs/authentik && ./scripts/setup-admin.sh)   # admin user + API token -> .env
task authentik:init && task authentik:plan && task authentik:apply

task authentik:test-auth | authentik:check-policies | authentik:status | authentik:health | authentik:logs
task authentik:redeploy       # clean slate (removes volumes)
task authentik:purge          # remove Terraform state and disable Vault OIDC auth
```

**Environment Requirements:**
The lab requires specific environment variables in `.env`:
- `AUTHENTIK_SECRET_KEY` - Generate with `openssl rand -base64 32`
- `AUTHENTIK_ADMIN_USER` - Admin username (default: akadmin)
- `AUTHENTIK_ADMIN_PASSWORD` - **REQUIRED** - Admin password (no default)
- `AUTHENTIK_TOKEN` - Auto-generated by `scripts/setup-admin.sh`
- `PG_PASS` - PostgreSQL password
- `AUTHENTIK_URL` - `http://authentik.localhost:9000` (for Terraform provider)

**Setup Script (`scripts/setup-admin.sh`):**
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

### `/labs/dex/`
Demonstrates Dex as a lightweight OIDC provider for Vault (root and admin namespaces).

**Optional lab:** Dex runs as its own compose project (`labs/dex/compose.yaml`) on the root stack's `docker-vault-stack` network (external). Storage is in-memory, so the container is stateless. Image tag is set by `DEX_TAG` (default `v2.45.1`, the minimum for groups in `staticPasswords`).

**Lab Commands:**
```bash
# From project root - start the core stack, then Dex
task up
task dex:all        # up + terraform init + apply

task dex:up | dex:down | dex:restart | dex:status | dex:health | dex:logs
task dex:plan | dex:apply | dex:destroy
```

### `/labs/pki/`
Demonstrates the PKI secrets engine with two imported intermediate CAs, templated AIA/CRL URLs and ACME, deployed into namespace `admin/tn001`.

**Key Features:**
- Root + intermediate CAs generated with the `tls` provider and imported via `issuers/import/bundle`
- Issuer-aware AIA/CRL/OCSP URL templating via `config/cluster`
- ACME with External Account Binding required; certbot demo on the `docker-vault-stack` network
- Roles `default`, `v1`, `v2` (v2 is the stricter role), auto-tidy, audit non-HMAC keys

Included in the root Taskfile as `pki` (like `authentik` and `dex`).

**Namespace gotcha:** the namespace is set once in `labs/pki/Taskfile.yml` and exported per task (YAML anchor `ns_env`) as `VAULT_NAMESPACE` and `TF_VAR_vault_namespace`. Top-level `env` in an included Taskfile leaks into root tasks, so don't move it there. Resource `namespace` is relative to the provider namespace, so Terraform must run with `VAULT_NAMESPACE` unset - use the `tf:*` tasks.

**Lab Commands (from repo root):**
```bash
task namespaces                 # admin, admin/tn001
task pki:tf:init && task pki:tf:apply
task pki:test                   # smoke tests
task pki:default-cert | pki:v1-cert | pki:v2-cert | pki:sign | pki:crl | pki:health-check
task pki:acme:init pki:acme:web pki:acme:certbot && task pki:acme:down
```

See `labs/pki/README.md` and `labs/pki/acme-demo.md`.

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
- Podman with `podman compose` (default runtime); Docker also works via `CONTAINER_RUNTIME=docker`
- Task runner: `brew install go-task jq`
- Terraform CLI
- Vault CLI
- Valid Vault Enterprise license (or modify `compose.yaml` for OSS)

### Typical Workflow
1. `task up` - Start stack
2. `task init` - Initialize Vault (first time)
3. `task unseal` - Unseal Vault
4. `task config` - Enable audit devices and set token TTLs
5. `source .env` - Load environment
   - `task namespaces` - Create base lab namespaces if the lab needs them
6. Work on labs: included labs (`authentik`, `dex`, `pki`) run from the root via `task <lab>:*`; the others via `terraform init/plan/apply` (or their own `task`) in the lab directory
7. `task clean` - Full cleanup when done

### Temporary Files
- Put all temporary files (logs, command output, scratch data, intermediate files) in `.tmp/` at the repo root (git-ignored); create it with `mkdir -p .tmp` if missing
- Never write temp files to `/tmp`, the repo root or `scripts/`; scripts and tasks follow the same rule (e.g. `scripts/10_vault_init.sh`, the `pki` lab's `TMP_DIR: .tmp`)
- Remove what you created in `.tmp/` once you're done with it

### Python Scripts
- Run with `uv run` (dependencies declared inline, PEP 723); lint/format with `uvx ruff check` and `uvx ruff format` (`ruff.toml`: line length 200, default rules)
- Catch Vault/HTTP errors only (`VAULT_ERRORS` in `scripts/seed_vault.py`), not bare `Exception`

### Debugging
- Vault logs: `task logs-vault`
- All services: `task logs`
- Vault status: `vault status`
- UI access: http://vault.localhost:8200 (Vault), http://grafana.localhost:3000 (Grafana)
- Grafana doesn't pick up dashboard file changes on its own under Podman; run `task grafana-reload`

## Important Notes

### Security Considerations
- The `.env` file contains sensitive tokens - never commit this
- Default setup uses Vault Enterprise - ensure license compliance
- All services expose ports locally - not for production use
- Grafana allows anonymous Admin access with the login form disabled (`GF_AUTH_*` in `compose.yaml`); `admin/admin` still works for the API
- TLS is disabled by default for easier deployment
- This is a training environment - production deployments should use TLS

### Container Runtime and Audit Logs
- Root and lab tasks use `{{.CONTAINER_RUNTIME}}` (default `podman`; override with `CONTAINER_RUNTIME=docker task up`). Lab Taskfiles (`authentik`, `dex`, `pki`) declare `CONTAINER_RUNTIME: '{{.CONTAINER_RUNTIME | default "podman"}}'` so they inherit the root value when included and still work standalone; scripts they call (`setup-admin.sh`, `acme-certbot.sh`) read `${CONTAINER_RUNTIME:-podman}` from the task env.
- Vault uses the image's own `docker-entrypoint.sh` as root (`command: ["server"]`, `SKIP_SETCAP=true` because the image has no `setcap` and `raft.hcl` disables mlock); it chowns `/vault/{config,file,logs}` and drops to the `vault` user.
- **Podman empty-volume ownership:** while a named volume is empty, Podman resets its root to the user of any container that mounts it. Alloy mounts `vault-logs` (read-only, as root) to ship `vault_audit.log` to Loki, which flips `/vault/logs` to `root:root`. `task config` therefore chowns `/vault/logs` right before `scripts/30_vault_config.sh` enables the `audit_log` file device; once the log file exists the volume keeps its ownership across restarts. Don't replace this with a startup-time chown.
- `scripts/30_vault_config.sh` is idempotent (skips existing audit devices) and fails loudly; the file device uses `mode=0644`.

### State Management
- Terraform state files are created in lab directories
- `vault-init.json` contains unseal keys and root token. `task init` (only after a successful `vault operator init`) and `task down` archive the previous copy to `.backups/vault-init-<timestamp>.json` via `scripts/archive_vault_init.sh`; never delete it directly
- Named volumes persist data between restarts (`task down` removes them)

### Resource Naming
When creating resources in labs, use consistent naming patterns:
- Providers: `vault.{namespace}` aliases
- Resources: Include namespace/bu identifier in name
- Outputs: Use descriptive names with map structures
