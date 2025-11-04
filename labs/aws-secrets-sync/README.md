# Vault AWS Secrets Manager Sync Lab

This lab demonstrates HashiCorp Vault's AWS Secrets Manager synchronization feature, which automatically syncs secrets from Vault to AWS Secrets Manager in real-time.

## Architecture

### Components
- **Namespace**: admin/tn001 (tenant-based isolation)
- **Secrets Engine**: KV v2 mount at `kv-sync`
- **Test Secrets**: Two example secrets demonstrating different use cases
  - `app1_secrets`: API keys for external services (SendGrid, Datadog)
  - `app2_secrets`: Webhook security secret
- **Sync Destination**: AWS Secrets Manager in eu-west-1
- **Granularity**: Secret-path level (entire secret syncs as one AWS secret)

### How It Works

1. Terraform activates the Vault secrets sync feature (one-time operation)
2. Secrets are stored in Vault KV v2 engine in the `admin/tn001` namespace
3. A sync destination is configured pointing to AWS Secrets Manager
4. Sync associations link individual Vault secrets to the AWS destination
5. Vault automatically syncs secrets to AWS in real-time
6. Each Vault secret syncs as a complete JSON object to AWS Secrets Manager
7. Custom tags are applied to all synced secrets for tracking

### Secret Naming Convention

Synced secrets in AWS follow this template:
```
vault/<mount_path>/<secret_path>
```

Example: `vault/kv-sync/app1_secrets`

With `granularity = "secret-path"`, the entire secret (all keys and values) syncs as a single JSON object in AWS Secrets Manager.

## Prerequisites

### Vault Setup
1. Vault Enterprise 1.16+ (with secrets sync feature)
2. Vault unsealed and accessible
3. Root or admin token for namespace management

**Note:** The secrets sync feature activation is handled automatically by Terraform using the `vault_generic_endpoint` resource. No manual activation is required.

### AWS Setup
1. AWS account with appropriate permissions
2. AWS credentials configured (via environment variables or AWS CLI)
3. IAM role for Vault to assume with Secrets Manager permissions

### IAM Configuration

The lab automatically creates an IAM role that Vault assumes to sync secrets to AWS Secrets Manager. The role is defined in `iam.tf` and includes:

**IAM Role**: `vault-secrets-sync-role` (configurable via `secrets_sync_role_name` variable)

**Trust Policy**: Automatically allows the current AWS session caller identity to assume the role. This can be overridden by specifying the `trust_policy_arns` variable.

**Permissions Granted**:
- Create, update, and delete secrets in AWS Secrets Manager
- Tag and untag secrets
- List secrets for verification
- Scope limited to secrets with `vault/*` prefix

**Auto-Detection (Default)**:
By default, the trust policy automatically allows your current AWS session to assume the role. No manual configuration is required.

```bash
# The lab automatically detects your current identity
aws sts get-caller-identity

# Apply without additional configuration
terraform apply
```

**Manual Configuration (Optional)**:
To specify different IAM principals or multiple principals, configure the `trust_policy_arns` variable in `terraform.tfvars`:

```hcl
# terraform.tfvars
trust_policy_arns = [
  "arn:aws:iam::123456789012:user/vault-user",
  "arn:aws:iam::123456789012:role/vault-automation-role"
]
```

**Verify Trust Policy**:
After applying, check which ARNs are configured:
```bash
terraform output trust_policy_arns
```

## Setup

### 1. Ensure Prerequisites

Make sure Vault is running and you have AWS credentials:

```bash
# Check Vault status
vault status

# Verify AWS credentials
aws sts get-caller-identity

# Set required environment variables
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_TOKEN=<your-root-token>
export AWS_ACCESS_KEY_ID=<your-aws-key>
export AWS_SECRET_ACCESS_KEY=<your-aws-secret>
export AWS_REGION=eu-west-1
```

### 2. Create Namespace (if needed)

Use the Taskfile automation to ensure the namespace exists:

```bash
# From repository root
task check-tn001-namespace
```

Or manually verify:

```bash
vault namespace list
vault namespace list -namespace=admin
```

### 3. Deploy Terraform Configuration

```bash
cd labs/aws-secrets-sync

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply configuration
terraform apply
```

### 4. Verify Deployment

Check the outputs for sync status:

```bash
terraform output synced_secrets
terraform output demo_workflow
```

## Testing the Sync

### 1. Read Secrets from Vault

```bash
# List all secrets
vault kv list -namespace=admin/tn001 kv-sync

# Read a specific secret
vault kv get -namespace=admin/tn001 kv-sync/app1_secrets
```

### 2. Verify Secrets in AWS

```bash
# List all Vault-managed secrets in AWS
aws secretsmanager list-secrets \
  --region eu-west-1 \
  --filters Key=tag-key,Values=ManagedBy

# Get specific secret value (replace with actual mount path, e.g., kv-sync)
# This returns the entire secret as a JSON object
aws secretsmanager get-secret-value \
  --region eu-west-1 \
  --secret-id vault/<mount_path>/app1_secrets \
  --query SecretString --output text | jq
```

### 3. Test Real-Time Sync

Update a secret in Vault and verify it syncs to AWS:

```bash
# Update secret in Vault
vault kv put -namespace=admin/tn001 kv-sync/app1_secrets \
  sendgrid_key=SG.new_key_updated_123.xyz789 \
  datadog_key=dd_api_key_updated_456

# Wait a few seconds for sync
sleep 5

# Verify updated value in AWS (returns complete JSON)
aws secretsmanager get-secret-value \
  --region eu-west-1 \
  --secret-id vault/<mount_path>/app1_secrets \
  --query SecretString --output text | jq
```

### 4. Monitor Sync Status

Use Terraform to check sync status:

```bash
# Refresh state and view sync details
terraform refresh
terraform output synced_secrets
```

The output shows:
- Vault path for each secret
- Sync status (SYNCED, PENDING, FAILED)
- List of synced subkeys
- Last update timestamp

### 5. Taskfile Automation

The lab includes Taskfile tasks for automated secret management and testing:

#### verify-sync

Checks the current sync destination associations status:

```bash
task verify-sync
```

This task displays:
- Sync destination type and name
- Current namespace
- Associated secrets in JSON format
- Sync status for all associations

Use this to monitor which secrets are currently synced to AWS and their status.

#### secrets:update

Updates secrets in Vault with new values to trigger AWS sync:

```bash
task secrets:update
```

This task:
- Updates all test secrets with timestamp-based values
- Automatically triggers AWS Secrets Manager sync
- Useful for testing real-time sync behavior

#### secrets:refresh

Refreshes Terraform state to check sync status:

```bash
task secrets:refresh
```

This task:
- Runs `terraform apply -refresh` for each secret resource
- Updates Terraform state with latest sync status
- Useful for verifying sync completion without modifying secrets

#### verify-aws

Verifies secrets exist in AWS Secrets Manager:

```bash
task verify-aws
```

This task displays:
- List of all Vault-managed secrets in AWS
- Secret names, ARNs, and creation dates
- Total count of synced secrets

## Key Features Demonstrated

### 1. Granular Sync Control

The lab uses `granularity = "secret-path"` which means:
- Each complete secret (with all key-value pairs) syncs as a single AWS secret
- Simpler management with one AWS secret per Vault secret
- Secret returned as a complete JSON object from AWS
- Ideal for related configuration values that should stay together

Alternative: `granularity = "secret-key"` splits each subkey into a separate AWS secret for fine-grained access control.

### 2. Custom Tagging

All synced secrets include custom tags:
```hcl
custom_tags = {
  "ManagedBy"   = "Vault"
  "Environment" = "training"
  "Namespace"   = "admin/tn001"
  "Source"      = "vault-secrets-sync"
}
```

Use tags for:
- Cost allocation
- Access policies
- Filtering and searching
- Compliance tracking

### 3. Template-Based Naming

The `secret_name_template` controls AWS secret names:
```hcl
secret_name_template = "vault/{{ .MountPath | lowercase }}/{{ .SecretPath | lowercase }}"
```

Available template variables:
- `{{ .MountAccessor }}` - Unique mount identifier (e.g., `auth_token_a1b2c3d4`)
- `{{ .MountPath }}` - Mount path (e.g., `kv-sync`) - used in this lab
- `{{ .SecretPath }}` - Secret path in Vault (e.g., `app1_secrets`)
- `{{ .Key }}` - Secret subkey (required when using `granularity = "secret-key"`)

### 4. Namespace Isolation

Secrets are isolated in the `admin/tn001` namespace:
- Multi-tenant architecture
- Separate sync configurations per namespace
- Independent access policies

## Terraform Configuration

### Automatic Feature Activation

The lab automatically activates the Vault secrets sync feature using `vault_generic_endpoint`:

```hcl
resource "vault_generic_endpoint" "activate_secrets_sync" {
  path           = "sys/activation-flags/secrets-sync/activate"
  disable_read   = true
  disable_delete = true

  data_json = "{}"
}
```

**Key points:**
- `disable_read = true`: The activation endpoint doesn't support read operations
- `disable_delete = true`: Activation is permanent and cannot be reversed
- All sync resources depend on this activation completing first
- This is a one-time operation; subsequent applies are idempotent

### Centralized Configuration

The lab uses locals for easy customization:

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

### Provider Aliases

Namespace-specific provider for scoped operations:

```hcl
provider "vault" {
  alias     = "tn001"
  namespace = "admin/tn001"
}
```

### Dynamic Resource Creation

Uses `for_each` to create secrets and associations dynamically:

```hcl
resource "vault_kv_secret_v2" "test_secrets" {
  for_each = local.test_secrets
  # Configuration...
}
```

## Troubleshooting

### Sync Status Shows PENDING

**Issue**: Secrets show PENDING status instead of SYNCED

**Solutions**:
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

3. Check Vault logs for errors:
   ```bash
   task logs-vault
   ```

### Sync Status Shows FAILED

**Issue**: Secrets fail to sync to AWS

**Solutions**:
1. Check AWS region matches configuration:
   ```bash
   echo $AWS_REGION
   terraform output aws_region
   ```

2. Verify secrets don't already exist in AWS:
   ```bash
   aws secretsmanager list-secrets --region eu-west-1
   ```

3. Check for AWS service limits or quotas

4. Review Vault audit logs:
   ```bash
   vault audit list
   ```

### Cannot Find Secrets in AWS

**Issue**: Secrets synced but not visible in AWS console

**Solutions**:
1. Verify region in AWS console matches `eu-west-1`

2. Use correct secret name format:
   ```bash
   # Get mount path from Terraform
   terraform output kv_mount_path

   # Search for secrets with that mount path
   aws secretsmanager list-secrets --filters Key=name,Values=vault/<mount_path>/
   ```

3. Check secret name template in Terraform output

### Authentication Errors

**Issue**: Vault cannot authenticate to AWS

**Solutions**:
1. Ensure environment variables are set:
   ```bash
   env | grep AWS
   ```

2. Verify credentials work with AWS CLI:
   ```bash
   aws s3 ls
   ```

3. Check for credential conflicts (profile vs environment variables)

4. Verify your IAM principal can assume the Vault sync role:
   ```bash
   # Test assuming the role
   aws sts assume-role \
     --role-arn $(terraform output -raw iam_role_arn) \
     --role-session-name test-session
   ```

5. Check which IAM principals are allowed in the trust policy:
   ```bash
   # View the auto-detected or configured ARNs
   terraform output trust_policy_arns

   # Check your current identity
   aws sts get-caller-identity

   # If manually configured, verify terraform.tfvars
   grep trust_policy_arns terraform.tfvars
   ```

### Namespace Not Found

**Issue**: Terraform fails with namespace not found error

**Solutions**:
1. Create namespace using Taskfile:
   ```bash
   task check-tn001-namespace
   ```

2. Manually create namespaces:
   ```bash
   vault namespace create admin
   vault namespace create -namespace=admin tn001
   ```

3. Verify namespace exists:
   ```bash
   vault namespace list -namespace=admin
   ```

## Cleanup

The lab includes automated cleanup tasks for safe and complete resource removal:

### Cleanup Tasks Reference

| Task | Description | When to Use |
|------|-------------|-------------|
| `task verify-sync` | Check sync status | Before cleanup to see what will be removed |
| `task cleanup-sync-destination` | Delete sync destination with purge | Remove sync destination and associations only |
| `task destroy` | Complete cleanup | Remove everything (recommended) |
| `task cleanup-aws` | Clean AWS secrets only | Remove orphaned AWS secrets after Terraform destroy |

### Option 1: Complete Cleanup (Recommended)

```bash
# Check what's currently synced
task verify-sync

# Destroy all Terraform-managed resources
task destroy

# Clean up AWS secrets (not removed by Terraform)
task cleanup-aws
```

The `task destroy` command runs `terraform destroy -auto-approve` to remove all Terraform-managed resources including:
- Vault secrets sync destination and associations
- KV secrets engine and test secrets
- IAM role and policies

**Important**: AWS Secrets Manager secrets are NOT automatically deleted by Terraform due to AWS deletion protection. After destroying Terraform resources, you must run `task cleanup-aws` to remove the synced secrets from AWS.

### Option 2: Step-by-Step Cleanup

If you need more control over the cleanup process:

```bash
# Step 1: Remove sync destination and associations
task cleanup-sync-destination

# Step 2: Destroy Terraform resources
terraform destroy

# Step 3: Clean up any remaining AWS secrets
task cleanup-aws
```

The `task cleanup-sync-destination` command:
- Extracts sync destination details from Terraform output
- Shows current association count
- Deletes the sync destination using Vault API with `purge=true` flag
- Verifies associations have been removed (gracefully handles expected errors)
- Uses the [Vault Secrets Sync API](https://developer.hashicorp.com/vault/api-docs/system/secrets-sync#delete-destination)

The `task cleanup-aws` command:
- Lists all Vault-managed secrets in AWS Secrets Manager
- Prompts for confirmation before deletion (unless SKIP_PROMPT=true)
- Force deletes secrets without recovery period
- Verifies cleanup completion

### Option 3: Manual Cleanup

If you prefer complete manual control:

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

**Important Notes**:
- The `purge=true` parameter is critical when deleting sync destinations - it forces removal of all associations
- AWS secrets are NOT automatically deleted by Terraform due to AWS deletion protection
- Always use `task cleanup-aws` or manually delete AWS secrets after running `task destroy`

## Additional Resources

- [Vault Secrets Sync Documentation](https://developer.hashicorp.com/vault/docs/sync)
- [Vault Secrets Sync API](https://developer.hashicorp.com/vault/api-docs/system/secrets-sync) - API reference for managing sync destinations and associations
- [AWS Secrets Manager Sync Guide](https://developer.hashicorp.com/vault/docs/sync/awssm)
- [Vault Provider: vault_secrets_sync_aws_destination](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/secrets_sync_aws_destination)
- [Vault Provider: vault_secrets_sync_association](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/secrets_sync_association)
