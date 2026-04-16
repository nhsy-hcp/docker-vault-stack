terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.12.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12.0"
    }
  }
}

provider "authentik" {
  # Uses AUTHENTIK_URL and AUTHENTIK_TOKEN from environment
}

provider "vault" {
  # Uses VAULT_ADDR and VAULT_TOKEN from environment
}

# # Vault provider aliases for namespaces
# provider "vault" {
#   alias = "admin"
#   # Uses VAULT_ADDR and VAULT_TOKEN from environment
#   namespace = "admin"
# }

# provider "vault" {
#   alias = "tn001"
#   # Uses VAULT_ADDR and VAULT_TOKEN from environment
#   namespace = "admin/tn001"
# }
