# docker-vault-stack

A Docker Compose stack for learning HashiCorp Vault Enterprise features with integrated monitoring and hands-on lab exercises.

## Components

- **Vault Enterprise** - Raft storage backend and audit logging
- **Monitoring** - Grafana (dashboards), Prometheus (metrics), Loki (logs), Alloy (collection)
- **Labs** - Self-contained exercises in [`labs/`](labs/), each with its own README

## Prerequisites

```bash
brew install go-task jq
brew tap hashicorp/tap && brew install hashicorp/tap/vault
docker --version && docker compose version
```

Copy `.env.example` to `.env` and set `VAULT_LICENSE`. `VAULT_TOKEN` is written by `task init`; do not edit it manually. The `.env` file is the source of environment configuration for all scripts and tasks.

## Quick Start

```bash
task up          # start the stack
task init        # initialize Vault (first time only)
task unseal      # unseal Vault
task config      # audit devices and token TTLs
source .env
vault status
```

After a restart: `task up unseal`. Clean reset: `task clean`, then repeat the steps above.

Run `task --list` for all tasks. Frequently used:

| Task | Description |
|------|-------------|
| `task namespaces` | Create base lab namespaces `admin` and `admin/tn001` (idempotent, not run by default) |
| `task backup` | Save a Raft snapshot to `.backups/` (git-ignored) |
| `task ui` | Open the Vault UI and print service URLs |
| `task logs` / `task logs-vault` | Follow service logs |
| `task benchmark` | Run vault-benchmark (requires the `vault-benchmark` CLI) |
| `task lint` | Run pre-commit hooks |

## Services

| Service | URL |
|---------|-----|
| Vault | http://vault.localhost:8200 |
| Grafana | http://grafana.localhost:3000 |
| Prometheus | http://prometheus.localhost:9090 |
| Loki | http://loki.localhost:3100 |
| Alloy | http://alloy.localhost:12345 |

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
- Never commit `.env`, `vault-init.json` or snapshots in `.backups/`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
