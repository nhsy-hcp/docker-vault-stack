# Audit Log Filtering Lab

## Overview

This lab demonstrates HashiCorp Vault's audit log filtering capabilities. Audit log filters allow you to reduce audit log volume by selectively capturing events based on specific criteria, such as namespace, authentication method, or other request attributes.

## What This Lab Demonstrates

The lab creates two file-based audit devices to illustrate the difference between filtered and unfiltered audit logging:

1. **Standard Audit Device** (`vault_benchmark`): Captures all audit events across the entire Vault instance
2. **Filtered Audit Device** (`vault_benchmark_filter`): Only captures audit events from the `vault-benchmark` namespace

This comparison helps visualize how audit filters can significantly reduce log volume in multi-tenant environments while maintaining compliance for specific workspaces.

## Prerequisites

- Vault stack running and unsealed (see root `README.md`)
- Terraform CLI installed
- Vault CLI configured with appropriate credentials
- `vault-benchmark` namespace created (`vault namespace create vault-benchmark`)

## Lab Setup

### 1. Deploy Audit Devices

```bash
cd labs/audit-logs
terraform init
terraform apply
```

This creates:
- Standard audit device writing to `/vault/logs/audit_vault_benchmark.log`
- Filtered audit device writing to `/vault/logs/audit_vault_benchmark_filter.log` (namespace-filtered)

### 2. Verify Audit Devices

```bash
vault audit list
```

Expected output:
```
Path                         Type    Description
----                         ----    -----------
vault_benchmark/             file    n/a
vault_benchmark_filter/      file    n/a
```

## Testing the Filter

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

## Filter Syntax

The audit filter uses the following expression:

```hcl
filter = "namespace == \"vault-benchmark/\""
```

### Filter Expression Capabilities

Vault audit filters support various expressions:

- **Namespace filtering**: `namespace == "myapp/"`
- **Path filtering**: `request.path contains "secrets"`
- **Authentication method**: `auth.token_type == "service"`
- **Operation type**: `request.operation == "create"`
- **Compound expressions**: `namespace == "prod/" and request.operation == "delete"`

For complete filter syntax documentation, see the [Vault Audit Device documentation](https://developer.hashicorp.com/vault/docs/audit).

## Use Cases

Audit log filtering is valuable for:

1. **Multi-tenant environments**: Reduce log volume by filtering to specific namespaces
2. **Compliance requirements**: Capture only events relevant to specific workloads or data classifications
3. **Cost optimization**: Reduce storage and log processing costs in high-volume environments
4. **Performance**: Lower I/O overhead by writing fewer audit entries
5. **Security focus**: Concentrate audit analysis on sensitive namespaces or operations

## Important Considerations

### Redundant Audit Devices

Vault requires at least one audit device to be enabled. For production environments:
- Always maintain redundant unfiltered audit devices for complete audit trails
- Use filtered devices as supplementary logging for specific use cases
- Never rely solely on filtered audit devices for compliance

### Filter Testing

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

## Additional Resources

- [Vault Audit Devices](https://developer.hashicorp.com/vault/docs/audit)
- [Audit Device Filter Expressions](https://developer.hashicorp.com/vault/docs/audit#filter)
- [Audit Log Format](https://developer.hashicorp.com/vault/docs/audit#log-format)