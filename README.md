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
Create `.env` file in the root directory:
```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_LICENSE=INSERT_LICENSE_HERE
```

> **License Options:**
> - Request enterprise trial: https://www.hashicorp.com/products/vault/trial
> - Use Vault BSL: Change `docker-compose.yml` to use `hashicorp/vault-enterprise:1.19`

## Quick Start

### Initial Setup
```bash
# 1. Create PKI certificates (if not done)
task setup-pki

# 2. Start the complete stack
task up

# 3. Initialize Vault (first time only)
task init

# 4. Unseal Vault
task unseal

# 5. Load environment variables
source .env

# 6. Verify setup
vault status
vault token lookup
```

### Accessing Services
- **Vault UI**: https://localhost:8200
- **Alloy**: http://localhost:12345
- **Grafana**: http://localhost:3000  
- **Prometheus**: http://localhost:9090
- **Loki**: http://localhost:3100

### Daily Usage
After initial setup, restart with:
```bash
task up unseal
source .env
```

## TLS Configuration

### Generate TLS Certificates
```bash
# Create new TLS certificates with 1-year validity
task setup-pki
```

This generates:
- `volumes/vault/localhost.key` - Private key
- `volumes/vault/localhost.crt` - Certificate with CN=localhost, SAN=localhost,127.0.0.1

## Available Tasks

The `Taskfile.yml` provides the following automation commands:

### Stack Management
- `task up` - Start complete Docker Compose stack
- `task vault-up` - Start only Vault service  
- `task down` - Stop all services
- `task stop` - Stop services (alias for down)
- `task restart` - Restart Vault service
- `task rm` / `task clean` - Remove containers and volumes completely

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

### TLS & Security
- `task create-cert` - Generate new TLS certificates for localhost

### Infrastructure
- `task pull` - Pull latest Docker images

## Performance Testing

Run benchmarks to test Vault performance and generate metrics:
```bash
# Create benchmark namespace
vault namespace create vault-benchmark

# Execute performance tests (requires vault-benchmark CLI)
task benchmark
```

## Troubleshooting

### Common Issues

**Vault Sealed After Restart:**
```bash
task unseal
```

**Permission Denied Errors:**
```bash
# Verify token
vault token lookup

# Check policies
vault token capabilities <path>
```

**Container Issues:**
```bash
# Check service status
docker compose ps

# View service logs  
task logs-vault
task logs
```

**Environment Issues:**
```bash
# Reload environment
source .env

# Verify variables
echo $VAULT_ADDR
echo $VAULT_TOKEN
```

### Clean Reset
```bash
# Complete cleanup and restart
task clean
task up
task init
task unseal
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
- **License Compliance**: Ensure Vault Enterprise license compliance
- **Secrets Management**: Never commit `.env` or `vault-init.json` files
- **TLS Configuration**: Use `task setup-pki` for proper TLS setup
- **Access Control**: Follow principle of least privilege in lab policies
