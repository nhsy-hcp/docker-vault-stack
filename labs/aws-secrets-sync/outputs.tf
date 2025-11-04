output "namespace_path" {
  description = "Full namespace path where secrets are configured"
  value       = var.namespace_path
}

output "kv_mount_path" {
  description = "KV v2 mount path in the namespace"
  value       = vault_mount.kv_sync.path
}

output "kv_mount_accessor" {
  description = "KV v2 mount accessor"
  value       = vault_mount.kv_sync.accessor
}

output "sync_destination_name" {
  description = "AWS Secrets Manager sync destination name"
  value       = vault_secrets_sync_aws_destination.aws_sm.name
}

output "sync_destination_type" {
  description = "Sync destination type"
  value       = vault_secrets_sync_aws_destination.aws_sm.type
}

output "aws_region" {
  description = "AWS region where secrets are synced"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID where secrets are synced"
  value       = data.aws_caller_identity.current.account_id
}

output "synced_secrets" {
  description = "Map of synced secret names and their association details"
  value = {
    for k, v in vault_secrets_sync_association.test_secrets : k => {
      vault_path  = "${var.namespace_path}/${vault_mount.kv_sync.path}/data/${v.secret_name}"
      mount       = v.mount
      secret_name = v.secret_name
      destination = v.name
      type        = v.type
      metadata    = v.metadata
    }
  }
}

output "vault_read_commands" {
  description = "Commands to read secrets from Vault"
  value = {
    for k, v in local.test_secrets : k => "vault kv get -namespace=${var.namespace_path} ${vault_mount.kv_sync.path}/${k}"
  }
}

output "aws_cli_commands" {
  description = "AWS CLI commands to verify synced secrets in AWS Secrets Manager"
  value = {
    list_secrets = "aws secretsmanager list-secrets --region ${var.aws_region} --filters Key=tag-key,Values=ManagedBy Key=tag-value,Values=Vault"
    # Note: secret-id matches secret_name_template format: vault/<mount_path>/<secret_path>
    get_secrets = {
      for k, v in local.test_secrets : k => "aws secretsmanager get-secret-value --region ${var.aws_region} --secret-id vault/${vault_mount.kv_sync.path}/${k} --query SecretString --output text | jq"
    }
  }
}

output "demo_workflow" {
  description = "Step-by-step demonstration commands"
  value       = <<-EOT
    # 1. Verify namespace exists
    vault namespace list
    vault namespace list -namespace=admin

    # 2. List secrets in Vault
    vault kv list -namespace=${var.namespace_path} ${vault_mount.kv_sync.path}

    # 3. Read a secret from Vault (example using first secret)
    vault kv get -namespace=${var.namespace_path} ${vault_mount.kv_sync.path}/${keys(local.test_secrets)[0]}

    # 4. List AWS Secrets Sync asssoications
    vault read -namespace=${var.namespace_path} -format=json sys/sync/destinations/${vault_secrets_sync_aws_destination.aws_sm.type}/${vault_secrets_sync_aws_destination.aws_sm.name}/associations | jq

    # 5. List synced secrets in AWS
    aws secretsmanager list-secrets --region ${var.aws_region} --filters Key=tag-key,Values=ManagedBy

    # 6. Get a synced secret from AWS (returns complete JSON)
    # Note: secret-id uses format from secret_name_template: vault/<mount_path>/<secret_path>
    aws secretsmanager get-secret-value --region ${var.aws_region} \
      --secret-id vault/${vault_mount.kv_sync.path}/${keys(local.test_secrets)[0]} \
      --query SecretString --output text | jq

    # 7. Update a secret in Vault and watch it sync
    vault kv patch -namespace=${var.namespace_path} ${vault_mount.kv_sync.path}/${keys(local.test_secrets)[0]} \
      sendgrid_key=SG.updated_key_xyz789

    # 8. Check sync status via Terraform
    terraform refresh
    terraform output synced_secrets
  EOT
}

output "iam_role_arn" {
  description = "ARN of the IAM role used by Vault for secrets sync"
  value       = aws_iam_role.vault_secrets_sync.arn
}

output "iam_role_name" {
  description = "Name of the IAM role used by Vault for secrets sync"
  value       = aws_iam_role.vault_secrets_sync.name
}

output "trust_policy_arns" {
  description = "IAM principal ARNs configured in the trust policy (auto-detected or explicitly configured)"
  value       = local.computed_trust_policy_arns
}
