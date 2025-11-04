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
