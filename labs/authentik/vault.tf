# Local variables
locals {
  vault_redirect_uris = [
    "http://localhost:8250/oidc/callback",
    "https://127.0.0.1:8200/ui/vault/auth/${var.vault_oidc_mount_path}/oidc/callback",
    "https://localhost:8200/ui/vault/auth/${var.vault_oidc_mount_path}/oidc/callback",
    "http://localhost:8200/ui/vault/auth/${var.vault_oidc_mount_path}/oidc/callback",
  ]

  vault_admin_redirect_uris = [
    "http://localhost:8250/oidc/callback",
    "https://127.0.0.1:8200/ui/vault/auth/${var.vault_oidc_mount_path}/oidc/callback",
    "https://localhost:8200/ui/vault/auth/${var.vault_oidc_mount_path}/oidc/callback",
    "http://localhost:8200/ui/vault/auth/${var.vault_oidc_mount_path}/oidc/callback",
  ]
}

# Create Vault Namespaces
resource "vault_namespace" "admin" {
  path = "admin"
}

resource "vault_namespace" "tn001" {
  namespace = vault_namespace.admin.path_fq
  path      = "tn001"
}

# OIDC Auth Backend - Root Namespace
resource "vault_jwt_auth_backend" "root" {
  path               = var.vault_oidc_mount_path
  type               = "oidc"
  oidc_client_id     = authentik_provider_oauth2.vault.client_id
  oidc_client_secret = authentik_provider_oauth2.vault.client_secret
  default_role       = "default"
  oidc_discovery_url = "${var.vault_authentik_url}/application/o/${authentik_application.vault.slug}/"
  namespace_in_state = true

  tune {
    default_lease_ttl = "1h"
    max_lease_ttl     = "8h"
    token_type        = "default-service"
  }
}

# OIDC Role - Root Namespace
resource "vault_jwt_auth_backend_role" "root" {
  backend         = vault_jwt_auth_backend.root.path
  role_name       = "default"
  token_policies  = ["default"]
  bound_audiences = [authentik_provider_oauth2.vault.client_id]

  bound_claims = {
    "groups" = authentik_group.groups["vault-admin"].name
  }
  bound_claims_type = "glob"

  user_claim            = "email"
  groups_claim          = "groups"
  oidc_scopes           = ["openid", "profile", "email", "groups"]
  allowed_redirect_uris = local.vault_redirect_uris

  token_bound_cidrs = ["192.168.0.0/16"]
}

# OIDC Auth Backend - Admin Namespace
resource "vault_jwt_auth_backend" "admin" {
  namespace          = vault_namespace.admin.path
  path               = var.vault_oidc_mount_path
  type               = "oidc"
  oidc_client_id     = authentik_provider_oauth2.vault.client_id
  oidc_client_secret = authentik_provider_oauth2.vault.client_secret
  default_role       = "default"
  oidc_discovery_url = "${var.vault_authentik_url}/application/o/${authentik_application.vault.slug}/"
  namespace_in_state = true

  tune {
    default_lease_ttl  = "1h"
    max_lease_ttl      = "8h"
    token_type         = "default-service"
    listing_visibility = "unauth"
  }
}

# OIDC Role - Admin Namespace
resource "vault_jwt_auth_backend_role" "admin" {
  namespace       = vault_namespace.admin.path
  backend         = vault_jwt_auth_backend.admin.path
  role_name       = "default"
  token_policies  = ["default"]
  bound_audiences = [authentik_provider_oauth2.vault.client_id]

  bound_claims = {
    "groups" = authentik_group.groups["vault-user"].name
  }
  bound_claims_type = "glob"

  user_claim            = "email"
  groups_claim          = "groups"
  oidc_scopes           = ["openid", "profile", "email", "groups"]
  allowed_redirect_uris = local.vault_admin_redirect_uris
}
