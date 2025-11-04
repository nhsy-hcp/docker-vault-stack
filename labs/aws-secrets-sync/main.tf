# Activate secrets sync feature (one-time operation)
# This enables Vault Enterprise secrets sync functionality
resource "vault_generic_endpoint" "activate_secrets_sync" {
  path           = "sys/activation-flags/secrets-sync/activate"
  disable_read   = true
  disable_delete = true

  data_json = "{}"
}

# Local configuration for test secrets
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

# Create KV v2 secrets engine in admin/tn001 namespace
resource "vault_mount" "kv_sync" {
  provider    = vault.tn001
  path        = var.kv_mount_path
  type        = "kv"
  description = "KV v2 secrets engine for AWS Secrets Manager sync demonstration"

  options = {
    version = "2"
  }
}

# Create test secrets
resource "vault_kv_secret_v2" "test_secrets" {
  provider = vault.tn001
  for_each = local.test_secrets

  mount     = vault_mount.kv_sync.path
  name      = replace(each.key, "_", "-")
  data_json = jsonencode(each.value.data)
}

# Get AWS account information
data "aws_caller_identity" "current" {}

# Create AWS Secrets Manager sync destination
resource "vault_secrets_sync_aws_destination" "aws_sm" {
  provider = vault.tn001
  name     = var.sync_destination_name
  region   = var.aws_region

  # IAM role assumption for authentication
  role_arn = aws_iam_role.vault_secrets_sync.arn

  # Custom tags for all synced secrets
  custom_tags = {
    "ManagedBy"   = "Vault"
    "Environment" = "training"
    "Namespace"   = var.namespace_path
    "Source"      = "vault-secrets-sync"
  }

  # Template for generating AWS secret names
  # Format: vault/<mount_path>/<secret_path>
  # https://developer.hashicorp.com/vault/docs/sync#name-template
  secret_name_template = var.secret_name_template

  # Sync at secret-path level
  # This means entire secret (with all keys) syncs as one AWS secret
  granularity = "secret-path"

  depends_on = [
    vault_generic_endpoint.activate_secrets_sync,
    aws_iam_role.vault_secrets_sync
  ]
}

# Add a delay to workaround authentication issues between destination and association creation
resource "time_sleep" "default" {
  create_duration = "10s"
  depends_on = [
    vault_secrets_sync_aws_destination.aws_sm
  ]
}

# Create sync associations for each test secret
resource "vault_secrets_sync_association" "test_secrets" {
  provider = vault.tn001
  for_each = local.test_secrets

  name        = vault_secrets_sync_aws_destination.aws_sm.name
  type        = vault_secrets_sync_aws_destination.aws_sm.type
  mount       = vault_mount.kv_sync.path
  secret_name = vault_kv_secret_v2.test_secrets[each.key].name

  depends_on = [
    vault_secrets_sync_aws_destination.aws_sm,
    vault_kv_secret_v2.test_secrets,
    time_sleep.default
  ]
}
