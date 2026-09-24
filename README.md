# docker-vault-stack

A Compose stack (Podman by default, Docker supported) for learning HashiCorp Vault Enterprise features with integrated monitoring and hands-on lab exercises.

## Components

- **Vault Enterprise** - Raft storage backend and audit logging
- **Monitoring** - Grafana (dashboards), Prometheus (metrics), Loki (logs), Alloy (collection)
- **Labs** - Self-contained exercises in [`labs/`](labs/), each with its own README

## Prerequisites

```bash
brew install go-task jq podman
brew tap hashicorp/tap && brew install hashicorp/tap/vault hashicorp/tap/terraform
podman machine init --rootful && podman machine start
podman --version && podman compose version
```

Tasks use Podman by default. To use Docker instead, set `CONTAINER_RUNTIME=docker` (e.g. `CONTAINER_RUNTIME=docker task up`).

Copy `.env.example` to `.env` and set `VAULT_LICENSE`. `VAULT_TOKEN` is written by `task init`; do not edit it manually. The `.env` file is the source of environment configuration for all scripts and tasks.

## Quick Start

```bash
task up          # start the stack
task init        # initialize Vault (first time only)
task unseal      # unseal Vault
task config      # file + stdout audit devices (shipped to Loki via Alloy) and token TTLs
source .env
vault status
```

`task init` and `task down` move an existing `vault-init.json` to `.backups/vault-init-<timestamp>.json` instead of overwriting or deleting it, so older snapshots stay restorable.

After a restart: `task up unseal`. Stop without losing data: `task stop`. Clean reset: `task clean` (removes all volumes including Vault data; prompts, `--yes` skips), then repeat the steps above.

Run `task --list` for all tasks. Frequently used:

| Task | Description |
|------|-------------|
| `task namespaces` | Create base lab namespaces `admin` and `admin/tn001` (idempotent, not run by default) |
| `task backup` | Save a Raft snapshot and a matching `vault-init.json` copy (unseal keys, root token) to `.backups/` (git-ignored) |
| `task seed` | Seed demo data: namespace tree `tn001`-`tn010` (children and `prod`/`staging`/`dev` grandchildren) with auth methods, KV, PKI, Transit, policies, identities and client logins (idempotent; needs `uv`) |
| `task ui` | Open the Vault UI and print service URLs |
| `task grafana-reload` | Reload Grafana dashboards after editing `volumes/grafana/dashboards/*.json` |
| `task logs` / `task logs-vault` | Follow service logs |
| `task benchmark` | Run vault-benchmark (requires the `vault-benchmark` CLI; run with `VAULT_ADDR=http://127.0.0.1:8200`, it can't resolve `*.localhost`) |
| `task lint` | Run pre-commit hooks |

## Services

| Service | URL |
|---------|-----|
| Vault | http://vault.localhost:8200 |
| Grafana | http://grafana.localhost:3000 (no login, anonymous Admin) |
| Prometheus | http://prometheus.localhost:9090 |
| Loki | http://loki.localhost:3100 |
| Alloy | http://alloy.localhost:12345 |

## Dashboards

Grafana loads these from `volumes/grafana/dashboards/`. Switch between them with the **Vault dashboards** menu at the top of each one.

| Dashboard | Source | Shows |
|-----------|--------|-------|
| Vault / Operational | Prometheus | Health, request traffic, runtime, seal, replication, snapshots |
| Vault / Integrated Storage | Prometheus | Raft leadership, commits, FSM and storage operations |
| Vault / Tokens | Prometheus | Token creation, counts and TTLs by namespace and auth method |
| Vault / Audit Logs | Loki | Audit requests, errors, top paths and identities (needs `task config`) |

The Prometheus dashboards open with a row of summary tiles (active node, Raft peers, license days left, ...). Replication, HA standby and snapshot panels stay empty on this single-node stack. After editing a dashboard's JSON, run `task grafana-reload`.

## Labs

| Lab | Description |
|-----|-------------|
| [ACL Templating](labs/acl-templating/README.md) | AppRole authentication with templated policies across namespaces |
| [Audit Logs](labs/audit-logs/README.md) | Audit log filtering |
| [Authentik](labs/authentik/README.md) | Authentik OIDC provider (optional lab, `task authentik:*`) |
| [AWS Secrets Sync](labs/aws-secrets-sync/README.md) | Sync secrets to AWS Secrets Manager |
| [Dex](labs/dex/README.md) | Dex OIDC provider (optional lab, `task dex:*`) |
| [Entra ID](labs/entra-id/README.md) | Azure Entra ID authentication |
| [PKI](labs/pki/README.md) | PKI with imported intermediate CAs and ACME (`task pki:*`) |

## Security Considerations

- Training and development use only: services are exposed on localhost over HTTP (no TLS)
- Ensure Vault Enterprise license compliance
- Grafana allows anonymous Admin access (no login); don't expose port 3000 beyond localhost
- Never commit `.env`, `vault-init.json` or anything in `.backups/` (snapshots and copies of the unseal keys)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
