# Generate random client ID and secret for OAuth2/OIDC
resource "random_id" "client_id" {
  byte_length = 16
}

resource "random_password" "client_secret" {
  length  = 32
  special = true
}

# Data sources for Authentik defaults
data "authentik_flow" "default_authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_invalidation" {
  slug = "default-invalidation-flow"
}

data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}

data "authentik_property_mapping_provider_scope" "openid" {
  managed = "goauthentik.io/providers/oauth2/scope-openid"
}

data "authentik_property_mapping_provider_scope" "profile" {
  managed = "goauthentik.io/providers/oauth2/scope-profile"
}

data "authentik_property_mapping_provider_scope" "email" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
}

# Create custom scope mapping for groups
resource "authentik_property_mapping_provider_scope" "groups" {
  name       = "vault-groups"
  scope_name = "groups"
  expression = "return {'groups': [group.name for group in user.ak_groups.all()]}"
}

# Create OAuth2/OIDC Provider for Vault
resource "authentik_provider_oauth2" "vault" {
  name               = "vault-${var.vault_oidc_mount_path}"
  client_id          = "vault-${random_id.client_id.hex}"
  client_secret      = random_password.client_secret.result
  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id

  allowed_redirect_uris = [
    for uri in local.vault_admin_redirect_uris : {
      matching_mode     = "strict"
      url               = uri
      redirect_uri_type = "authorization"
    }
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.email.id,
    authentik_property_mapping_provider_scope.groups.id,
  ]

  signing_key = data.authentik_certificate_key_pair.default.id
}

# Create vault-user group first (no parent)
resource "authentik_group" "vault_user" {
  name = "vault-user"
  attributes = jsonencode({
    description = "Standard Vault users"
  })
}

# Create all other groups with vault-user as parent
resource "authentik_group" "groups" {
  for_each = { for k, v in var.authentik_groups : k => v if k != "vault-user" }

  name = each.key
  attributes = jsonencode({
    description = each.value.description
  })
  parents = [
    authentik_group.vault_user.id
  ]
}

# Create Users
resource "authentik_user" "users" {
  for_each = var.authentik_users

  username = each.key
  name     = each.value.display_name
  email    = each.value.email
  password = each.value.password
  groups = [
    for g in each.value.groups :
    g == "vault-user" ? authentik_group.vault_user.id : authentik_group.groups[g].id
  ]
}

# Create policy bindings to allow vault-admin and vault-user groups access
resource "authentik_policy_binding" "vault_admin" {
  target = authentik_application.vault.uuid
  group  = authentik_group.groups["vault-admin"].id
  order  = 0
}

resource "authentik_policy_binding" "vault_user" {
  target = authentik_application.vault.uuid
  group  = authentik_group.vault_user.id
  order  = 1
}

# Create Application
resource "authentik_application" "vault" {
  name              = "HashiCorp Vault"
  slug              = "vault"
  protocol_provider = authentik_provider_oauth2.vault.id
  meta_launch_url   = "http://vault.localhost:8200"

  backchannel_providers = var.enable_scim ? [
    tonumber(authentik_provider_scim.vault[0].id),
  ] : []
}
