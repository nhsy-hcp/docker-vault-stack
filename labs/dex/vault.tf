resource "vault_namespace" "admin" {
  path = "admin"
}

resource "vault_namespace" "tn001" {
  namespace = vault_namespace.admin.path_fq
  path      = "tn001"
}

# Enable the JWT auth method for root namespace
resource "vault_jwt_auth_backend" "root" {
  path               = var.vault_oidc_mount_path
  type               = "oidc"
  oidc_client_id     = "vault"
  oidc_client_secret = "vault-secret"
  default_role       = "default"
  oidc_discovery_url = "http://dex.localhost:5556"
  namespace_in_state = true
  tune {
    default_lease_ttl  = "6h"
    max_lease_ttl      = "24h"
    token_type         = "default-service"
    listing_visibility = "unauth"
  }
}

resource "vault_jwt_auth_backend_role" "root" {
  backend         = vault_jwt_auth_backend.root.path
  role_name       = "default"
  token_policies  = ["default"]
  bound_audiences = ["vault"]
  user_claim      = "email"
  groups_claim    = "groups"
  oidc_scopes     = ["openid", "profile", "email", "groups"]

  allowed_redirect_uris = local.redirect_uris
}

# Enable the JWT auth method for admin namespace
resource "vault_jwt_auth_backend" "admin" {
  namespace          = vault_namespace.admin.path
  path               = var.vault_oidc_mount_path
  type               = "oidc"
  oidc_client_id     = "vault"
  oidc_client_secret = "vault-secret"
  default_role       = "default"
  oidc_discovery_url = "http://dex.localhost:5556"
  namespace_in_state = true
  tune {
    default_lease_ttl  = "6h"
    max_lease_ttl      = "24h"
    token_type         = "default-service"
    listing_visibility = "unauth"
  }
}

resource "vault_jwt_auth_backend_role" "admin" {
  namespace       = vault_namespace.admin.path
  backend         = vault_jwt_auth_backend.admin.path
  role_name       = "default"
  token_policies  = ["default"]
  bound_audiences = ["vault"]
  user_claim      = "email"
  groups_claim    = "groups"
  oidc_scopes     = ["openid", "profile", "email", "groups"]

  allowed_redirect_uris = local.redirect_uris
}
