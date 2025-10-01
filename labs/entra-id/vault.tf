resource "vault_namespace" "admin" {
  path = "admin"
}

resource "vault_namespace" "tn001" {
  namespace = vault_namespace.admin.path_fq
  path      = "tn001"
}

# Enable the JWT auth method for root namespace
resource "vault_jwt_auth_backend" "root" {
  path               = "azure"
  type               = "oidc"
  oidc_client_id     = azuread_application.vault.client_id
  oidc_client_secret = azuread_application_password.vault.value
  default_role       = "default"
  oidc_discovery_url = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"
  namespace_in_state = true
  tune {
    default_lease_ttl = "6h"
    max_lease_ttl     = "24h"
    token_type        = "default-service"
    # listing_visibility = "unauth"
  }
}

resource "vault_jwt_auth_backend_role" "root" {
  backend         = vault_jwt_auth_backend.root.path
  role_name       = "default"
  token_policies  = ["default"]
  bound_audiences = [azuread_application.vault.client_id]
  bound_claims = {
    "groups" = azuread_group.groups["vault-admin"].object_id
  }
  user_claim   = "upn"
  groups_claim = "groups"
  oidc_scopes  = ["https://graph.microsoft.com/.default", "profile"]

  allowed_redirect_uris = local.redirect_uris
  # verbose_oidc_logging  = true

  claim_mappings = {
    name = "name"
    oid  = "oid"
    upn  = "upn"
  }
}

# Enable the JWT auth method for admin namespace
resource "vault_jwt_auth_backend" "admin" {
  namespace          = vault_namespace.admin.path
  path               = "azure"
  type               = "oidc"
  oidc_client_id     = azuread_application.vault.client_id
  oidc_client_secret = azuread_application_password.vault.value
  default_role       = "default"
  oidc_discovery_url = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"
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
  bound_audiences = [azuread_application.vault.client_id]
  bound_claims = {
    "groups" = azuread_group.groups["vault-user"].object_id
  }
  user_claim   = "upn"
  groups_claim = "groups"
  oidc_scopes  = ["https://graph.microsoft.com/.default", "profile"]

  allowed_redirect_uris = local.redirect_uris
  # verbose_oidc_logging  = true

  claim_mappings = {
    name = "name"
    oid  = "oid"
    upn  = "upn"
  }
}
