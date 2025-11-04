variable "aws_region" {
  description = "AWS region for Secrets Manager destination"
  type        = string
  default     = "eu-west-1"
}

variable "namespace_path" {
  description = "Vault namespace path for secrets sync"
  type        = string
  default     = "admin/tn001"
}

variable "kv_mount_path" {
  description = "KV v2 mount path for source secrets"
  type        = string
  default     = "kv-sync"
}

variable "sync_destination_name" {
  description = "Name for the AWS Secrets Manager sync destination"
  type        = string
  default     = "aws-sm-eu-west-1"
}

variable "secrets_sync_role_name" {
  description = "Name for the IAM role used by Vault for secrets sync"
  type        = string
  default     = "vault-secrets-sync-role"
}

variable "secret_name_template" {
  description = "Template for generating AWS secret names"
  type        = string
  default     = "vault/{{ .MountPath | lowercase }}/{{ .SecretPath | lowercase }}"
}

variable "trust_policy_arns" {
  description = "List of IAM principal ARNs allowed to assume the vault-secrets-sync-role. If not specified, defaults to the current AWS session caller identity ARN"
  type        = list(string)
  default     = []
}
