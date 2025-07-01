terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

locals {
  teams = {
    team01 = "team1"
    team02 = "team2"
    team03 = "team3"
  }

  approle_config = {
    token_ttl      = 900
    token_max_ttl  = 3600
    bind_secret_id = true
  }

  # Configuration for userpass demo with namespace-specific access
  userpass_users = {
    alice = {
      namespace = "bu01"
      password  = "password123"
    }
    bob = {
      namespace = "bu02"
      password  = "password123"
    }
    jim = {
      namespace = "bu03"
      password  = "password123"
    }
  }
}

# ==============================================================================
# SHARED LOCALS AND DATA SOURCES
# ==============================================================================

# AppRole accessors (computed after resources are created)
locals {
  approle_accessors = {
    bu01 = vault_auth_backend.approle_bu01.accessor
    bu02 = vault_auth_backend.approle_bu02.accessor
    bu03 = vault_auth_backend.approle_bu03.accessor
  }
}


resource "vault_namespace" "bu01" {
  path = "bu01"
}

resource "vault_namespace" "bu02" {
  path = "bu02"
}

resource "vault_namespace" "bu03" {
  path = "bu03"
}