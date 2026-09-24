# Dex + Vault OIDC Lab

Lightweight lab for Dex OIDC integration with Vault.

## Requirements

- **Dex v2.45.1+** - Groups support in `staticPasswords` requires Dex v2.45.1 or later (feature added in [#4456](https://github.com/dexidp/dex/issues/4456))
- **Note**: The image is pinned via `DEX_TAG` (default `v2.45.1`) in the root `.env`.

## Quick Start

This is an **optional lab**. Dex runs as its own compose project (`dex`) attached to the
root stack's `docker-vault-stack` network, so Vault reaches it at `http://dex.localhost:5556`.

```bash
# From project root
task up          # Start the core stack (creates the shared network)
task unseal
task dex:all     # Start Dex + terraform init/apply
```

### Tasks

```bash
task dex:up        # Start Dex (core stack must be running)
task dex:down      # Stop Dex (stateless - memory storage)
task dex:restart   # Restart Dex (e.g. after editing dex-config.yaml)
task dex:status    # Container status
task dex:health    # Health check
task dex:logs      # Tail logs
task dex:init      # terraform init
task dex:plan      # terraform plan (sources root .env)
task dex:apply     # terraform apply (sources root .env)
task dex:destroy   # terraform destroy (with prompt)
```

`task down` from the project root also stops Dex. The image tag is set by `DEX_TAG` in `.env`
(default `v2.45.1`).

## Usage

- **Discovery URL:** `http://dex.localhost:5556`
- **Client ID:** `vault`
- **Client Secret:** `vault-secret`
- **Users:**
  - `vaultadmin@localhost` / `password` (groups: `vault-admin`)
  - `testuser1@localhost` / `password` (groups: `vault-user`, `vault-tn001-team1-reader`)
  - `testuser2@localhost` / `password` (groups: `vault-user`, `vault-tn001-team2-reader`)

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

## Adding Users

1. Edit `dex-config.yaml`
2. Add a new entry to `staticPasswords` with groups
3. Generate a bcrypt hash for the password:
   ```bash
   echo "yourpassword" | htpasswd -BinC 10 admin | cut -d: -f2
   ```
4. Restart Dex: `task dex:restart`

## Testing

### Via Vault UI

**Root Namespace:**
- Navigate to: http://vault.localhost:8200
- Select: OIDC (dex-oidc)
- Login with: `vaultadmin@localhost` / `password`

**Admin Namespace:**
- Navigate to: http://vault.localhost:8200/ui/vault/auth?namespace=admin
- Select: OIDC (dex-oidc)
- Login with: `testuser1@localhost` / `password`

### Via Vault CLI

```bash
# Root namespace
vault login -method=oidc -path=dex-oidc

# Admin namespace
vault login -namespace=admin -method=oidc -path=dex-oidc
```
