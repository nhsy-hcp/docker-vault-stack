# docker-vault-stack

A Docker Compose stack for learning HashiCorp Vault Enterprise features with integrated monitoring and hands-on lab exercises.

## Architecture & Components

This environment provides:

### Core Stack
- **Vault Enterprise** - Main service with Raft storage backend and audit logging
- **Monitoring Stack** - Complete observability suite:
  - **Grafana** - Dashboards and visualization
  - **Prometheus** - Metrics collection and alerting  
  - **Loki** - Log aggregation
  - **Alloy** - Metrics collection

### Training Labs
Located in `/labs/` with specific Vault feature demonstrations:
- **ACL Templating** - AppRole & Userpass authentication with dynamic policies
- **AWS Authentication** - IAM role-based authentication
- **Certificate Authentication** - TLS client certificate authentication
- **Cross-Namespace Secrets** - Secret sharing across namespaces
- **Entra ID Integration** - Azure AD authentication and identity management
- **Namespace Management** - Multi-tenant isolation and access control
- **PKI Operations** - Public Key Infrastructure management

## Prerequisites

**Required Tools:**
```bash
# Install task runner and jq
brew install go-task jq

# Install Vault CLI
brew tap hashicorp/tap
brew install hashicorp/tap/vault

# Ensure you have Docker and Docker Compose
docker --version
docker compose version
```

**Clone Repository:**
```bash
git clone https://github.com/nhsy-hcp/docker-vault-stack.git
cd docker-vault-stack
```

**Environment Configuration:**
Copy `.env.example` to `.env` and configure:
1. Add your Vault Enterprise license to `VAULT_LICENSE`
2. `VAULT_ADDR` is pre-configured as `http://localhost:8200`

> **License Options:**
> - Request enterprise trial: https://www.hashicorp.com/products/vault/trial
> - Use Vault BSL: Change `docker-compose.yml` to use `hashicorp/vault-enterprise:1.19`

## Quick Start

### Initial Setup
```bash
# 1. Start the complete stack
task up

# 2. Initialize Vault (first time only)
task init

# 3. Unseal Vault
task unseal

# 4. Config Vault
task config

# 5. Load environment variables
source .env

# 6. Verify setup
vault status
vault token lookup
```

### Accessing Services
- **Vault UI**: http://localhost:8200
- **Alloy**: http://localhost:12345
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090
- **Loki**: http://localhost:3100

### Daily Usage
After initial setup, restart with:
```bash
task up unseal
source .env
vault token lookup
```

## Environment Variables

The `.env` file is the authoritative source for environment configuration. All scripts and Taskfile tasks source values from this file.

**Required Variables:**
- `VAULT_ADDR` - Vault server address (default: `http://localhost:8200`)
- `VAULT_TOKEN` - Root token (auto-populated by `task init` do not edit manually)
- `VAULT_LICENSE` - Vault Enterprise license key

**Note:** Scripts will fail with clear error messages if `.env` is missing or `VAULT_ADDR` is not set.

## Available Tasks

The `Taskfile.yml` provides the following automation commands:

### Stack Management
- `task up` - Start complete Docker Compose stack
- `task vault-up` - Start only Vault service  
- `task down` - Stop all services
- `task stop` - Stop services (alias for down)
- `task restart` - Restart Vault service
- `task clean` - Remove containers and volumes completely

### Vault Operations  
- `task init` - Initialize Vault (first time setup)
- `task unseal` - Unseal Vault after restart
- `task status` - Check Vault status
- `task backup` - Create Raft snapshot backup
- `task shell` - Access Vault container shell

### Monitoring & Metrics
- `task metrics` - Fetch Vault metrics endpoint
- `task logs` - Follow logs for all services
- `task logs-vault` - Follow Vault-specific logs

### Development & Testing
- `task benchmark` - Run vault-benchmark performance tests
- `task dev` - Start Vault in development mode
- `task ui` - Open Vault UI in browser
- `task config` - Run Vault configuration scripts
- `task token` - Copy Vault token to clipboard (macOS only)

## Performance Testing

Run benchmarks to test Vault performance and generate metrics:
```bash
# Execute performance tests (requires vault-benchmark CLI)
task benchmark
```

## Troubleshooting
### Clean Reset
```bash
# Complete cleanup and restart
task clean
task up
task init
task unseal
task config
source .env
```

## Development

### File Structure
```
├── docker-compose.yml          # Complete stack definition
├── Taskfile.yml               # Automation commands  
├── volumes/                   # Persistent data
│   ├── vault/                # Vault configuration & data
│   ├── alloy/                # Metrics / logs collection
│   ├── grafana/              # Grafana dashboards
│   ├── loki/                 # Loki logs
│   └── prometheus/           # Prometheus configuration
├── labs/                     # Training exercises
│   ├── acl-templating/       # Advanced ACL patterns
│   ├── aws-auth/            # Cloud authentication
│   ├── cert-auth/           # Certificate authentication
│   ├── cross-namespace-secrets/ # Multi-tenant secrets
│   ├── entra-id/            # Azure AD integration
│   ├── namespaces/          # Multi-tenancy basics
│   └── pki/                 # PKI operations
└── scripts/                 # Initialization scripts
```

## Security Considerations

- **Development Use Only**: This stack exposes services on localhost - not for production
- **TLS Disabled**: TLS is disabled by default for easier deployment
- **License Compliance**: Ensure Vault Enterprise license compliance
- **Secrets Management**: Never commit `.env` or `vault-init.json` files

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Note: This project is intended for training and development environments.*
