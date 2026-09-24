# Dex OIDC Lab

Lightweight lab for Dex OIDC integration with Vault, with OIDC authentication in the root and admin namespaces.

> **Optional lab:** Dex runs as its own compose project (`dex`) on the `docker-vault-stack` network, so Vault reaches it at `http://dex.localhost:5556`; start the core stack first.

## Overview

What this lab demonstrates:

- Dex as a lightweight OIDC provider for Vault, with static users and group membership defined in `dex-config.yaml`
- Vault OIDC auth method mounted at `dex-oidc` in the root and admin namespaces
- Groups passed to Vault in the ID token for group-based access
- Stateless Dex container (in-memory storage)

## Prerequisites

- Core stack running and unsealed (see the [root README](../../README.md))
- **Dex v2.45.1+** - Groups support in `staticPasswords` requires Dex v2.45.1 or later (feature added in [#4456](https://github.com/dexidp/dex/issues/4456)). The image is pinned via `DEX_TAG` (default `v2.45.1`) in the root `.env`.

## Quick Start

```bash
# From project root
task up          # Start the core stack (creates the shared network)
task unseal
task dex:all     # Start Dex + terraform init/apply
```

## Usage

### Connection Details

- **Discovery URL:** `http://dex.localhost:5556`
- **Client ID:** `vault`
- **Client Secret:** `vault-secret`
- **Users:**
  - `vaultadmin@localhost` / `password` (groups: `vault-admin`)
  - `testuser1@localhost` / `password` (groups: `vault-user`, `vault-tn001-team1-reader`)
  - `testuser2@localhost` / `password` (groups: `vault-user`, `vault-tn001-team2-reader`)

### Login via Vault UI

**Root Namespace:**

- Navigate to: http://vault.localhost:8200
- Select: OIDC (dex-oidc)
- Login with: `vaultadmin@localhost` / `password`

**Admin Namespace:**

- Navigate to: http://vault.localhost:8200/ui/vault/auth?namespace=admin
- Select: OIDC (dex-oidc)
- Login with: `testuser1@localhost` / `password`

### Login via Vault CLI

```bash
# Root namespace
vault login -method=oidc -path=dex-oidc

# Admin namespace
vault login -namespace=admin -method=oidc -path=dex-oidc
```

### Add Users

1. Edit `dex-config.yaml`
2. Add a new entry to `staticPasswords` with groups
3. Generate a bcrypt hash for the password:

   ```bash
   echo "yourpassword" | htpasswd -BinC 10 admin | cut -d: -f2
   ```

4. Restart Dex: `task dex:restart`

## Configuration

### Groups Support

Groups are automatically included in the ID token when:

1. Using Dex v2.45.1 or later
2. Groups are defined in `staticPasswords` configuration
3. Client requests the `groups` scope (Vault does this automatically)

Example configuration:

```yaml
oauth2:
  skipApprovalScreen: true

staticClients:
- id: vault
  secret: vault-secret
  redirectURIs:
  - 'http://vault.localhost:8200/ui/vault/auth/dex-oidc/oidc/callback'
  idTokensExpiry: "24h"

staticPasswords:
- email: "admin@localhost"
  hash: "$2y$10$..."
  username: "admin"
  userID: "08a8684b-db88-4b73-90a9-3cd1661f5466"
  groups:
  - "vault-admin"
```

## Available Tasks

Run from the project root:

| Task | Description |
|------|-------------|
| `dex:all` | Complete setup workflow (up + init + apply) |
| `dex:up` | Start Dex (core stack must be running) |
| `dex:down` | Stop Dex (stateless - memory storage) |
| `dex:restart` | Restart Dex (e.g. after editing `dex-config.yaml`) |
| `dex:status` | Container status |
| `dex:health` | Health check |
| `dex:logs` | Tail logs |
| `dex:init` | `terraform init` |
| `dex:plan` | `terraform plan` (sources root `.env`) |
| `dex:apply` | `terraform apply` (sources root `.env`) |
| `dex:destroy` | `terraform destroy` (with prompt) |

## Cleanup

```bash
task dex:destroy   # terraform destroy (with prompt)
task dex:down      # Stop Dex (stateless - memory storage)
```

`task down` from the project root also stops Dex.
