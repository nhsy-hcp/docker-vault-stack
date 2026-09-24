terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.8.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9.0"
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
