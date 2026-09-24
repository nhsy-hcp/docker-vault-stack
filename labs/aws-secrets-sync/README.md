# AWS Secrets Sync Lab

This lab demonstrates Vault Enterprise secrets sync, which automatically pushes secrets from a Vault KV v2 engine to AWS Secrets Manager in near real time.

> **Namespace:** `admin/tn001`

## Overview

What this lab demonstrates:

- Automatic activation of the secrets sync feature via Terraform (no manual step)
- An AWS Secrets Manager sync destination in `eu-west-1`, authenticated by an IAM role that Vault assumes
- Secret-path granularity: each Vault secret syncs as one AWS secret holding a complete JSON object
- Template-based AWS secret naming and custom tags for tracking, cost allocation, access policies and compliance
- Namespace isolation: the sync configuration lives in `admin/tn001`, separate from other tenants

### Architecture

- **Namespace**: `admin/tn001` (tenant-based isolation)
- **Secrets engine**: KV v2 mount at `kv-sync`
- **Test secrets**:
  - `app1-secrets`: API keys for external services (SendGrid, Datadog)
  - `app2-secrets`: webhook security secret
- **Sync destination**: AWS Secrets Manager in `eu-west-1` (`aws-sm-eu-west-1`)
- **IAM role**: `vault-secrets-sync-role`, created by `iam.tf` and assumed by Vault
- **Granularity**: `secret-path` (entire secret syncs as one AWS secret)

### How It Works

1. Terraform activates the secrets sync feature (one-time operation).
2. Test secrets are written to the `kv-sync` KV v2 engine in `admin/tn001`.
3. A sync destination is configured for AWS Secrets Manager, using the IAM role.
4. Sync associations link each Vault secret to the destination (after a 10 second `time_sleep` that works around authentication issues between destination and association creation).
5. Vault syncs each secret to AWS as a complete JSON object and applies the custom tags; later changes in Vault sync automatically.

### Secret Naming Convention

Synced secrets in AWS are named `vault/<mount_path>/<secret_path>`, for example `vault/kv-sync/app1-secrets`.

The alternative `granularity = "secret-key"` would instead split each subkey into a separate AWS secret for fine-grained access control.

### IAM Role

The role grants Vault permission to create, update, delete, read, describe, tag and untag secrets whose names start with `vault/`, plus `ListSecrets` for verification.

By default the trust policy allows the current AWS session caller identity to assume the role, so no manual configuration is required. To trust different or multiple principals, set `trust_policy_arns` in `terraform.tfvars`:

```hcl
# terraform.tfvars
trust_policy_arns = [
  "arn:aws:iam::123456789012:user/vault-user",
  "arn:aws:iam::123456789012:role/vault-automation-role"
]
```

## Prerequisites

- Core stack running and unsealed (see the [root README](../../README.md))
- Vault Enterprise 1.16+ with the secrets sync feature, and a root or admin token for namespace management
- The `admin/tn001` namespace (created by `task prereqs` in this lab, or `task namespaces` from the repository root)
- An AWS account with permissions to manage IAM roles/policies and Secrets Manager secrets
- AWS credentials configured via environment variables or the AWS CLI
- AWS CLI and `jq` installed

```bash
# Check Vault status
vault status

# Verify AWS credentials
aws sts get-caller-identity

# Set required environment variables
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=<your-root-token>
export AWS_ACCESS_KEY_ID=<your-aws-key>
export AWS_SECRET_ACCESS_KEY=<your-aws-secret>
export AWS_REGION=eu-west-1
```

## Quick Start

```bash
cd labs/aws-secrets-sync

# Create namespace if needed, init, plan, apply, show outputs and verify AWS
task all
```

## Usage

### Deploy Step by Step

```bash
cd labs/aws-secrets-sync

# Ensure admin/tn001 exists
task prereqs

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply configuration
terraform apply

# Check sync details and the full demo command list
terraform output synced_secrets
terraform output demo_workflow

# Check which IAM principals the trust policy allows
terraform output trust_policy_arns
```

### Read Secrets from Vault

```bash
# List all secrets
vault kv list -namespace=admin/tn001 kv-sync

# Read a specific secret
vault kv get -namespace=admin/tn001 kv-sync/app1-secrets
```

### Verify Secrets in AWS

```bash
# List all Vault-managed secrets in AWS
aws secretsmanager list-secrets \
  --region eu-west-1 \
  --filters Key=tag-key,Values=ManagedBy

# Get specific secret value
# This returns the entire secret as a JSON object
aws secretsmanager get-secret-value \
  --region eu-west-1 \
  --secret-id vault/kv-sync/app1-secrets \
  --query SecretString --output text | jq
```

`task verify-aws` lists the same secrets as a table (name, ARN, creation date) with a total count.

### Test Real-Time Sync

```bash
# Update secret in Vault
vault kv put -namespace=admin/tn001 kv-sync/app1-secrets \
  sendgrid_key=SG.new_key_updated_123.xyz789 \
  datadog_key=dd_api_key_updated_456

# Wait a few seconds for sync
sleep 5

# Verify updated value in AWS (returns complete JSON)
aws secretsmanager get-secret-value \
  --region eu-west-1 \
  --secret-id vault/kv-sync/app1-secrets \
  --query SecretString --output text | jq
```

### Monitor Sync Status

```bash
# Show destination associations and their sync status (with synced/total counts)
task verify-sync

# Or refresh Terraform state and view sync details
terraform refresh
terraform output synced_secrets
```

The `synced_secrets` output shows the Vault path, destination and association metadata (sync status such as `SYNCED`, `PENDING` or `FAILED`, synced subkeys and last update time) for each secret.

## Configuration

### Terraform Structure

| File | Purpose |
|------|---------|
| `main.tf` | Sync activation, KV v2 mount, test secrets, AWS destination, `time_sleep`, sync associations |
| `iam.tf` | IAM trust policy, Secrets Manager policy, `vault-secrets-sync-role` and attachment |
| `providers.tf` | AWS provider, default Vault provider and `vault.tn001` alias (`namespace = "admin/tn001"`) |
| `variables.tf` | Input variables |
| `outputs.tf` | Outputs |

Test secrets are defined in a single `local.test_secrets` map and created with `for_each`, as are the sync associations:

```hcl
locals {
  test_secrets = {
    app1_secrets = {
      description = "app1 secrets"
      data = {
        sendgrid_key = "SG.abc123def456.xyz789"
        datadog_key  = "dd_api_key_abc123"
      }
    }
    app2_secrets = {
      description = "app2 secrets"
      data = {
        webhook_secret = "webhook_verify_secret_123"
      }
    }
  }
}
```

Map keys use underscores; the Vault secret names replace them with hyphens (`app1-secrets`, `app2-secrets`).

### Feature Activation

```hcl
resource "vault_generic_endpoint" "activate_secrets_sync" {
  path           = "sys/activation-flags/secrets-sync/activate"
  disable_read   = true
  disable_delete = true

  data_json = "{}"
}
```

- `disable_read = true`: the activation endpoint does not support reads
- `disable_delete = true`: activation is permanent and cannot be reversed
- All sync resources depend on activation; subsequent applies are idempotent

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `eu-west-1` | AWS region for the Secrets Manager destination |
| `namespace_path` | `admin/tn001` | Vault namespace path for secrets sync |
| `kv_mount_path` | `kv-sync` | KV v2 mount path for source secrets |
| `sync_destination_name` | `aws-sm-eu-west-1` | Name of the sync destination |
| `secrets_sync_role_name` | `vault-secrets-sync-role` | IAM role name used by Vault |
| `secret_name_template` | `vault/{{ .MountPath \| lowercase }}/{{ .SecretPath \| lowercase }}` | Template for AWS secret names |
| `trust_policy_arns` | `[]` | IAM principals allowed to assume the role; empty means the current caller identity |

### Outputs

| Output | Description |
|--------|-------------|
| `namespace_path` | Namespace where secrets are configured |
| `kv_mount_path` | KV v2 mount path |
| `kv_mount_accessor` | KV v2 mount accessor |
| `sync_destination_name` | Sync destination name |
| `sync_destination_type` | Sync destination type |
| `aws_region` | AWS region where secrets are synced |
| `aws_account_id` | AWS account ID |
| `synced_secrets` | Map of synced secrets and association details |
| `vault_read_commands` | Commands to read secrets from Vault |
| `aws_cli_commands` | AWS CLI commands to verify synced secrets |
| `demo_workflow` | Step-by-step demonstration commands |
| `iam_role_arn` | ARN of the Vault sync IAM role |
| `iam_role_name` | Name of the Vault sync IAM role |
| `trust_policy_arns` | Principals in the trust policy (auto-detected or configured) |

### Custom Tags

All synced secrets receive these tags:

```hcl
custom_tags = {
  "ManagedBy"   = "Vault"
  "Environment" = "training"
  "Namespace"   = var.namespace_path
  "Source"      = "vault-secrets-sync"
}
```

### Name Template

```hcl
secret_name_template = "vault/{{ .MountPath | lowercase }}/{{ .SecretPath | lowercase }}"
```

| Template Variable | Description |
|-------------------|-------------|
| `{{ .MountAccessor }}` | Unique mount identifier (e.g. `auth_token_a1b2c3d4`) |
| `{{ .MountPath }}` | Mount path (e.g. `kv-sync`), used in this lab |
| `{{ .SecretPath }}` | Secret path in Vault (e.g. `app1-secrets`) |
| `{{ .Key }}` | Secret subkey (required with `granularity = "secret-key"`) |

## Available Tasks

Run these from `labs/aws-secrets-sync`.

| Task | Description |
|------|-------------|
| `task all` | Complete setup: `prereqs`, `init`, `plan`, `apply`, `output`, `verify-aws` |
| `task prereqs` | Check and create the `admin` and `admin/tn001` namespaces if missing |
| `task init` | Initialize Terraform |
| `task plan` | Plan Terraform changes |
| `task apply` | Apply Terraform configuration (`-auto-approve`) |
| `task output` | Show Terraform outputs |
| `task verify-sync` | Show destination type/name, namespace, associations JSON and synced/total counts |
| `task verify-aws` | List Vault-managed secrets in AWS (name, ARN, creation date) and the total count |
| `task secrets:update` | Write timestamped `username`/`password` values to the test secret paths to trigger a sync |
| `task secrets:refresh` | Replace the sync associations (`terraform apply -replace`), then run `verify-aws` and `verify-sync` |
| `task cleanup-sync-destination` | Delete the sync destination with `purge=true` and remove associations from Terraform state |
| `task destroy` | Run `terraform destroy -auto-approve` |
| `task cleanup-aws` | Force delete Vault-managed secrets from AWS Secrets Manager (prompts unless `SKIP_PROMPT=true`) |

## Troubleshooting

### Sync Status Shows PENDING

1. Check AWS credentials are valid:
   ```bash
   aws sts get-caller-identity
   ```

2. Verify IAM role and permissions:
   ```bash
   # Check the IAM role exists
   terraform output iam_role_arn

   # Verify role trust policy
   aws iam get-role --role-name vault-secrets-sync-role

   # Check attached policies
   aws iam list-attached-role-policies --role-name vault-secrets-sync-role
   ```

3. Check Vault logs for errors (from the repository root):
   ```bash
   task logs-vault
   ```

### Sync Status Shows FAILED

1. Check AWS region matches configuration:
   ```bash
   echo $AWS_REGION
   terraform output aws_region
   ```

2. Verify secrets don't already exist in AWS:
   ```bash
   aws secretsmanager list-secrets --region eu-west-1
   ```

3. Check for AWS service limits or quotas.

4. Review Vault audit logs:
   ```bash
   vault audit list
   ```

### Cannot Find Secrets in AWS

1. Verify the region in the AWS console is `eu-west-1`.

2. Use the correct secret name format:
   ```bash
   # Get mount path from Terraform
   terraform output kv_mount_path

   # Search for secrets with that mount path
   aws secretsmanager list-secrets --filters Key=name,Values=vault/<mount_path>/
   ```

3. Check the `secret_name_template` variable.

### Authentication Errors

Vault cannot authenticate to AWS.

1. Ensure environment variables are set, and check for conflicts between an AWS profile and environment variables:
   ```bash
   env | grep AWS
   ```

2. Verify credentials work with AWS CLI:
   ```bash
   aws s3 ls
   ```

3. Verify your IAM principal can assume the Vault sync role:
   ```bash
   # Test assuming the role
   aws sts assume-role \
     --role-arn $(terraform output -raw iam_role_arn) \
     --role-session-name test-session
   ```

4. Check which IAM principals are allowed in the trust policy:
   ```bash
   # View the auto-detected or configured ARNs
   terraform output trust_policy_arns

   # Check your current identity
   aws sts get-caller-identity

   # If manually configured, verify terraform.tfvars
   grep trust_policy_arns terraform.tfvars
   ```

### Namespace Not Found

Terraform fails with a namespace not found error.

```bash
# Create namespaces with the lab task
task prereqs

# Or create them manually
vault namespace create admin
vault namespace create -namespace=admin tn001

# Verify namespace exists
vault namespace list -namespace=admin
```

## Cleanup

AWS Secrets Manager secrets are not deleted by Terraform, so always remove them with `task cleanup-aws` (or manually) after destroying the Terraform resources. When deleting a sync destination directly, `purge=true` is required to force removal of all its associations.

### Complete Cleanup (Recommended)

```bash
# Check what's currently synced
task verify-sync

# Destroy all Terraform-managed resources (sync destination and associations, KV engine and secrets, IAM role and policy)
task destroy

# Clean up AWS secrets (not removed by Terraform)
task cleanup-aws
```

### Step-by-Step Cleanup

```bash
# Step 1: Remove sync destination and associations
task cleanup-sync-destination

# Step 2: Destroy Terraform resources
terraform destroy

# Step 3: Clean up any remaining AWS secrets
task cleanup-aws
```

`task cleanup-sync-destination` reads the destination details from Terraform outputs, shows the association count, deletes the destination via the [Vault Secrets Sync API](https://developer.hashicorp.com/vault/api-docs/system/secrets-sync#delete-destination) with `purge=true`, verifies the associations are gone and removes them from Terraform state.

### Manual Cleanup

```bash
# Delete sync destination via API
curl -sk -X DELETE \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -H "X-Vault-Namespace: admin/tn001" \
  "$VAULT_ADDR/v1/sys/sync/destinations/aws-sm/<destination-name>?purge=true"

# Destroy Terraform resources
terraform destroy

# Manually delete synced secrets in AWS:
aws secretsmanager list-secrets --region eu-west-1 --filters Key=tag-key,Values=ManagedBy
aws secretsmanager delete-secret --region eu-west-1 --secret-id <secret-id> --force-delete-without-recovery
```

## References

- [Vault Secrets Sync Documentation](https://developer.hashicorp.com/vault/docs/sync)
- [Vault Secrets Sync API](https://developer.hashicorp.com/vault/api-docs/system/secrets-sync) - API reference for managing sync destinations and associations
- [AWS Secrets Manager Sync Guide](https://developer.hashicorp.com/vault/docs/sync/awssm)
- [Vault Provider: vault_secrets_sync_aws_destination](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/secrets_sync_aws_destination)
- [Vault Provider: vault_secrets_sync_association](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/secrets_sync_association)
