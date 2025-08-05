variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "azure_groups" {
  description = "Map of Azure AD groups to create"
  type = map(object({
    display_name = string
    description  = string
  }))
  default = {}
}

variable "azure_users" {
  description = "Map of Azure AD users to create"
  type = map(object({
    display_name      = string
    given_name        = string
    surname           = string
    password          = string
    group_memberships = list(string)
  }))
  default = {}
}

variable "existing_users" {
  description = "Map of existing Azure AD users with their group memberships"
  type = map(object({
    groups = list(string)
  }))
  default = {}
}