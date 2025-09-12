# PKI Lab - HashiCorp Vault PKI Secrets Engine

This lab demonstrates HashiCorp Vault's PKI (Public Key Infrastructure) secrets engine with multiple intermediate Certificate Authorities (CAs) and certificate management capabilities.

Private TLS keys are stored in terraform state and is **NOT** suitable for production use. 


## Lab Overview

This lab sets up a complete PKI hierarchy with:
- A Root Certificate Authority (self-signed)
- Two Intermediate Certificate Authorities (v1 and v2)
- Vault PKI secrets engine configured with imported intermediate CAs
- Certificate roles for different use cases

### Architecture

```
Root CA (Self-Signed, 1 year validity)
├── Intermediate CA v1 (90 days validity)
│   └── Certificate Role: v1 (1-24 hour certificates)
└── Intermediate CA v2 (90 days validity)
    └── Certificate Role: v2 (1-24 hour certificates)
```

## Prerequisites

- Vault 
- Terraform >= 1.0
- OpenSSL (for certificate inspection)

## Quick Start
1. Create `.env` file with required environment variables:
  ```bash
  VAULT_ADDR=http://127.0.0.1:8200
  VAULT_TOKEN=<your_vault_token>
  ```


2. Initialize and apply Terraform configuration:
```bash
   terraform init
   terraform plan
   terraform apply
```

3. Verify PKI setup:
```bash
   vault list pki/issuers
   vault list pki/roles
```

4. Issue test certificates:
   ```bash
   # Using default role (uses default issuer - v1)
   task default-cert
   
   # Using v1 issuer explicitly
   task v1-cert
   
   # Using v2 issuer
   task v2-cert
   ```

## File Structure

```
labs/pki/
├── README.md              # This file
├── main.tf                # Local values and certificate bundles
├── pki.tf                 # Vault PKI secrets engine configuration
├── tls.tf                 # TLS certificate generation (Root + Intermediates)
├── outputs.tf             # Terraform outputs for certificates and IDs
├── variables.tf           # Input variables
├── Taskfile.yml           # Task automation for certificate operations
└── .env                   # Environment variables
```

## Key Components

### 1. Certificate Authority Generation (`tls.tf`)

- **Root CA**: Self-signed certificate with 1-year validity
- **Intermediate v1**: Signed by Root CA, 90-day validity
- **Intermediate v2**: Signed by Root CA, 90-day validity
- All CAs use 4096-bit RSA keys

### 2. Vault PKI Configuration (`pki.tf`)

- **PKI Mount**: `/pki` path with 90-day max TTL
- **Certificate Import**: Imports intermediate CA bundles (cert + key)
- **Issuer Configuration**: Named issuers for v1 and v2 intermediates
- **URL Configuration**: CRL and OCSP endpoints
- **Auto-tidy**: Automatic cleanup of expired certificates

### 3. Certificate Roles

- **default**: Uses default issuer (v1)
- **v1**: Explicitly uses intermediate v1 issuer
- **v2**: Explicitly uses intermediate v2 issuer

## Available Tasks

Use the `task` command to run common operations:

| Task | Description |
|------|-------------|
| `task default-cert` | Issue certificate using default role |
| `task v1-cert` | Issue certificate using v1 issuer |
| `task v2-cert` | Issue certificate using v2 issuer |
| `task crl` | View Certificate Revocation List |
| `task certs` | List all certificates |
| `task certs-list` | Detailed certificate listing |
| `task certs-count` | Count issued certificates |
| `task certs-detailed` | Full certificate details |
| `task leases` | Show certificate leases |
| `task health-check` | PKI health check |
| `task tidy-now` | Manual certificate cleanup |
| `task tidy-status` | Auto-tidy status |

## Certificate Operations
### Issue a Certificate
```bash
# Using Vault CLI directly
vault write pki/issue/default \
    common_name="app.example.com" \
    alt_names="api.example.com,web.example.com" \
    ip_sans="127.0.0.1" \
    format=pem

# Using specific issuer
vault write pki/issue/v1 common_name="test.example.com"
```

### Revoke a Certificate

```bash
# Get certificate serial number
vault list pki/certs

# Revoke using serial number
vault write pki/revoke serial_number="<serial>"
```

### Certificate Inspection

```bash
# View certificate details
vault read pki/cert/<serial>

# Request certificate and inspect with OpenSSL
vault read -field=certificate pki/cert/<serial> | openssl x509 -text -noout
```

## Issuer Management

### Switch Default Issuer

To change the default issuer from v1 to v2:

1. Modify `pki.tf`:
   ```hcl
   resource "vault_pki_secret_backend_config_issuers" "config" {
     backend = vault_mount.pki.path
     default = vault_pki_secret_backend_issuer.intermediate_v2.issuer_id
     # default = vault_pki_secret_backend_issuer.intermediate_v1.issuer_id
     default_follows_latest_issuer = false
   }
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

### View Issuer Information

```bash
# List all issuers
vault list pki/issuers

# Get issuer details
vault read pki/issuer/<issuer_id>

# View issuer certificate
vault read -field=certificate pki/issuer/<issuer_id> | openssl x509 -text -noout
```

## Monitoring and Maintenance

### Health Checks

```bash
# PKI health check
vault pki health-check pki

# Check specific issuer
vault pki health-check -issuer=<issuer_id> pki
```

## Troubleshooting
### Common Issues

1. **Certificate Import Fails**
   ```bash
   # Check certificate format
   openssl x509 -in certs/intermediate-v1.pem -text -noout
   
   # Verify certificate chain
   openssl verify -CAfile certs/root-ca.pem certs/intermediate-v1.pem
   
   # Verify leaf certificate
    openssl verify -CAfile <(cat certs/root-ca.pem certs/intermediate-v1.pem) <(vault write -field=certificate pki/issue/v1 common_name="test.example.com" ttl=1m)
   ```

2. **Role Configuration Errors**
   ```bash
   # Check role configuration
   vault read pki/roles/default
   
   # Test certificate issuance
   vault write -f pki/issue/default common_name=test.example.com
   ```

3. **CRL Issues**
   ```bash
   # Force CRL rotation
   vault write pki/crl/rotate
   
   # Check CRL status
   vault read pki/crl/rotate
   ```

### Debug Commands

```bash
# Check PKI mount status
vault read sys/mounts/pki

# Validate certificate chain
task health-check
```

## References

- [Vault PKI Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/pki)
- [Vault PKI Secrets Engine (API)](https://developer.hashicorp.com/vault/api-docs/secret/pki)
- [PKI Best Practices](https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine)

