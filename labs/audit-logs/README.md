# Audit Log Filtering Lab

This lab demonstrates HashiCorp Vault's audit log filtering capabilities. Audit log filters allow you to reduce audit log volume by selectively capturing events based on specific criteria, such as namespace, mount or operation.

> **Namespace:** filters on `vault-benchmark` (must already exist).

## Overview

The lab creates two file-based audit devices to illustrate the difference between filtered and unfiltered audit logging:

- **Standard Audit Device** (`vault_benchmark`): Captures all audit events across the entire Vault instance
- **Filtered Audit Device** (`vault_benchmark_filter`): Only captures audit events from the `vault-benchmark` namespace

This comparison helps visualize how audit filters can significantly reduce log volume in multi-tenant environments while maintaining compliance for specific workspaces.

### Use Cases

Audit log filtering is valuable for:

- **Multi-tenant environments**: Reduce log volume by filtering to specific namespaces
- **Compliance requirements**: Capture only events relevant to specific workloads or data classifications
- **Cost optimization**: Reduce storage and log processing costs in high-volume environments
- **Performance**: Lower I/O overhead by writing fewer audit entries
- **Security focus**: Concentrate audit analysis on sensitive namespaces or operations

## Prerequisites

- Core stack running and unsealed (see the [root README](../../README.md))
- Terraform CLI installed
- Vault CLI configured with appropriate credentials
- `jq` installed (used for log analysis)
- `vault-benchmark` namespace created (`vault namespace create vault-benchmark`)

## Quick Start

```bash
cd labs/audit-logs
terraform init
terraform apply
```

This creates:

- Standard audit device writing to `/vault/logs/audit_vault_benchmark.log`
- Filtered audit device writing to `/vault/logs/audit_vault_benchmark_filter.log` (namespace-filtered)

## Usage

### Verify Audit Devices

```bash
vault audit list
```

Expected output:

```text
Path                         Type    Description
----                         ----    -----------
vault_benchmark/             file    n/a
vault_benchmark_filter/      file    n/a
```

### Generate Audit Events

Create activity in different namespaces to observe filtering behavior:

```bash
# Activity in vault-benchmark namespace (will appear in both logs)
vault kv put -namespace=vault-benchmark secret/test value=filtered

# Activity in root namespace (will only appear in standard log)
vault kv put secret/test value=unfiltered

# Activity in another namespace (will only appear in standard log)
vault namespace create other
vault kv put -namespace=other secret/test value=unfiltered
```

### Compare Log Output

Access the Vault container and compare log files:

```bash
# View standard audit log (all events)
docker exec -it vault cat /vault/logs/audit_vault_benchmark.log | jq -s 'length'

# View filtered audit log (vault-benchmark namespace only)
docker exec -it vault cat /vault/logs/audit_vault_benchmark_filter.log | jq -s 'length'
```

The filtered log should contain significantly fewer entries, only those related to the `vault-benchmark` namespace.

### Detailed Log Analysis

Examine specific entries:

```bash
# Standard log - shows all namespaces
docker exec -it vault cat /vault/logs/audit_vault_benchmark.log | jq -r '.request.namespace'

# Filtered log - shows only vault-benchmark namespace
docker exec -it vault cat /vault/logs/audit_vault_benchmark_filter.log | jq -r '.request.namespace'
```

## Configuration

### Filter Syntax

The filtered audit device (`main.tf`) uses the following expression:

```hcl
filter = "namespace == \"vault-benchmark/\""
```

### Filter Expression Capabilities

Vault audit filters support expressions over the request properties `namespace`, `path`, `operation`, `mount_type` and `mount_point`:

- **Namespace filtering**: `namespace == "myapp/"`
- **Path filtering**: `path contains "secrets"`
- **Mount type**: `mount_type == "kv"`
- **Operation type**: `operation == "create"`
- **Compound expressions**: `namespace == "prod/" and operation == "delete"`

For complete filter syntax documentation, see the [Vault audit filtering documentation](https://developer.hashicorp.com/vault/docs/enterprise/audit/filtering).

### Production Considerations

#### Redundant Audit Devices

Filtered audit devices should not be your only source of audit data. For production environments:

- Always maintain redundant unfiltered audit devices for complete audit trails
- Use filtered devices as supplementary logging for specific use cases
- Never rely solely on filtered audit devices for compliance

#### Filter Testing

Before deploying filters in production:

1. Test filter expressions thoroughly in non-production environments
2. Verify that filtered logs capture expected events
3. Ensure unfiltered backup audit devices are configured
4. Document filter logic and retention policies

## Cleanup

To remove the audit devices:

```bash
terraform destroy
```

Or manually:

```bash
vault audit disable vault_benchmark
vault audit disable vault_benchmark_filter
```

## References

- [Vault Audit Devices](https://developer.hashicorp.com/vault/docs/audit)
- [Vault Audit Filtering](https://developer.hashicorp.com/vault/docs/enterprise/audit/filtering)
- [Audit Device Filter Expressions](https://developer.hashicorp.com/vault/docs/audit#filter)
- [Audit Log Format](https://developer.hashicorp.com/vault/docs/audit#log-format)
