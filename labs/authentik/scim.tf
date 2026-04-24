# ---------------------------------------------------------------------------
# Vault SCIM Lab
#
# Provisions SCIM 2.0 integration between Authentik and Vault Enterprise.
# All resources are gated on var.enable_scim.
#
# Flow:
#   Authentik SCIM provider  -->  Vault /identity/scim/v2  (root namespace)
#
# Prerequisites:
#   - Vault Enterprise (SCIM is not available in OSS)
#   - enable_scim = true in terraform.tfvars
# ---------------------------------------------------------------------------

locals {
  scim_name = "authentik-scim"
}

# Lookup the token auth mount accessor for root namespace (needed for entity aliases)
data "vault_auth_backend" "token" {
  count = var.enable_scim ? 1 : 0
  path  = "token"
}

# Default SCIM property mappings from Authentik
data "authentik_property_mapping_provider_scim" "user" {
  count   = var.enable_scim ? 1 : 0
  managed = "goauthentik.io/providers/scim/user"
}

data "authentik_property_mapping_provider_scim" "group" {
  count   = var.enable_scim ? 1 : 0
  managed = "goauthentik.io/providers/scim/group"
}

# ---------------------------------------------------------------------------
# 1. Activate Vault SCIM feature flag (one-time, irreversible)
# ---------------------------------------------------------------------------

resource "vault_generic_endpoint" "scim_activate" {
  count = var.enable_scim ? 1 : 0

  path                 = "sys/activation-flags/enable-scim/activate"
  disable_read         = true
  disable_delete       = true
  ignore_absent_fields = true
  data_json            = "{}"
}

# ---------------------------------------------------------------------------
# 2. SCIM client setup
# ---------------------------------------------------------------------------

resource "vault_policy" "scim" {
  count = var.enable_scim ? 1 : 0

  name   = local.scim_name
  policy = <<-EOT
    path "identity/scim/v2/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
  EOT
}

resource "vault_identity_entity" "scim" {
  count = var.enable_scim ? 1 : 0

  name = local.scim_name
  metadata = {
    description = "Vault entity for Authentik SCIM client"
  }
}

resource "vault_identity_entity_alias" "scim" {
  count = var.enable_scim ? 1 : 0

  name           = local.scim_name
  mount_accessor = data.vault_auth_backend.token[0].accessor
  canonical_id   = vault_identity_entity.scim[0].id
}

resource "vault_token_auth_backend_role" "scim" {
  count = var.enable_scim ? 1 : 0

  role_name               = local.scim_name
  allowed_entity_aliases  = [vault_identity_entity_alias.scim[0].name]
  orphan                  = true
  token_no_default_policy = true
  token_period            = 86400 # 24 hours
  allowed_policies        = [vault_policy.scim[0].name]
}

resource "vault_token" "scim" {
  count = var.enable_scim ? 1 : 0

  display_name      = local.scim_name
  no_default_policy = true
  period            = "24h"
  renewable         = true
  role_name         = vault_token_auth_backend_role.scim[0].role_name

  depends_on = [vault_token_auth_backend_role.scim]
}

resource "vault_generic_endpoint" "scim_client" {
  count = var.enable_scim ? 1 : 0

  path                 = "identity/scim/client/authentik"
  ignore_absent_fields = true
  disable_read         = true
  disable_delete       = false

  data_json = jsonencode({
    access_grant_principal = vault_identity_entity.scim[0].id
  })
  depends_on = [
    vault_generic_endpoint.scim_activate
  ]

}

# ---------------------------------------------------------------------------
# 3. Authentik SCIM providers
# ---------------------------------------------------------------------------

resource "authentik_provider_scim" "vault" {
  count = var.enable_scim ? 1 : 0

  name                    = "vault-${local.scim_name}"
  url                     = "${var.vault_scim_addr}/v1/identity/scim/v2"
  token                   = try(vault_token.scim[0].client_token, "")
  property_mappings       = [data.authentik_property_mapping_provider_scim.user[0].id]
  property_mappings_group = [data.authentik_property_mapping_provider_scim.group[0].id]
}
