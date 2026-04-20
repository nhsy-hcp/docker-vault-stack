variable "vault_authentik_url" {
  description = "Authentik server URL for Vault OIDC (use Docker service name - Vault and Authentik are on same network)"
  type        = string
  default     = "http://authentik.localhost:9000"
}

variable "vault_oidc_mount_path" {
  description = "Path to mount OIDC auth method"
  type        = string
  default     = "authentik"
}

variable "authentik_groups" {
  description = "Map of Authentik groups to create"
  type = map(object({
    description = string
  }))
  default = {
    "vault-admin" = {
      description = "Vault administrators with full access"
    }
    "vault-user" = {
      description = "Standard Vault users"
    }
    "vault-tn001-team1-reader" = {
      description = "Team 1 readers in tenant tn001"
    }
    "vault-tn001-team2-reader" = {
      description = "Team 2 readers in tenant tn001"
    }
  }
}

variable "authentik_users" {
  description = "Map of Authentik users to create"
  type = map(object({
    display_name = string
    email        = string
    password     = string
    groups       = list(string)
  }))
  default = {
    "vaultadmin" = {
      display_name = "Vault Administrator"
      email        = "vaultadmin@example.com"
      password     = "ChangeMe123!"
      groups       = ["vault-admin"]
    }
    "testuser1" = {
      display_name = "Test User 1"
      email        = "testuser1@example.com"
      password     = "ChangeMe123!"
      groups       = ["vault-user", "vault-tn001-team1-reader"]
    }
    "testuser2" = {
      display_name = "Test User 2"
      email        = "testuser2@example.com"
      password     = "ChangeMe123!"
      groups       = ["vault-user", "vault-tn001-team2-reader"]
    }
  }
}
