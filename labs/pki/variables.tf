variable "organization_name" {
  description = "Organization name for certificates"
  type        = string
  default     = "ACME Corp"
}

variable "vault_namespace" {
  description = "Vault namespace that hosts the PKI mount (relative to the provider namespace)"
  type        = string
  default     = "admin/tn001"
}

variable "vault_cluster_addr" {
  description = "Vault address used in templated AIA, CRL, OCSP and ACME URLs"
  type        = string
  default     = "http://vault.localhost:8200"
}
