locals {
  redirect_uris = [
    "http://localhost:8250/oidc/callback",
    "https://localhost:8200/ui/vault/auth/entra/oidc/callback",
    "https://127.0.0.1:8200/ui/vault/auth/entra/oidc/callback",
  ]
}

data "azuread_client_config" "current" {}

data "azuread_domains" "tenant" {
  only_default = true
}

data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}

resource "azuread_application" "vault" {
  display_name = "vault"
  # owners       = [data.azuread_client_config.current.object_id]

  feature_tags {
    enterprise = true
    gallery    = false
    # hide       = true
  }

  web {
    redirect_uris = local.redirect_uris
  }

  group_membership_claims = ["SecurityGroup"]

  optional_claims {
    id_token {
      name = "groups"
    }
    id_token {
      name = "upn"
    }
    id_token {
      name = "given_name"
    }
    id_token {
      name = "family_name"
    }
  }
  required_resource_access {
    # resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      # id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.Read"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["GroupMember.Read.All"]
      type = "Scope"
    }

    # resource_access {
    #   # id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" # Directory.Read.All
    #   id   = azuread_service_principal.msgraph.app_role_ids["Directory.Read.All"]
    #   type = "Role"
    # }

    # resource_access {
    #   id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["Group.Read.All"]
    #   type = "Scope"
    # }
  }
}

resource "azuread_application_password" "vault" {
  application_id = azuread_application.vault.id
  display_name   = "vault-client-secret"
}

resource "azuread_service_principal" "vault" {
  client_id                    = azuread_application.vault.client_id
  use_existing                 = true
  app_role_assignment_required = true
}

# resource "azuread_app_role_assignment" "user_read_all" {
#   # Assign the User.Read.All permission to the Vault service principal
#   app_role_id         = azuread_service_principal.msgraph.app_role_ids["User.Read.All"]
#   principal_object_id = azuread_service_principal.vault.object_id
#   resource_object_id  = azuread_service_principal.msgraph.object_id
# }
#
# resource "azuread_app_role_assignment" "group_read_all" {
#   # Assign the Group.Read.All permission to the Vault service principal
#   app_role_id         = azuread_service_principal.msgraph.app_role_ids["Group.Read.All"]
#   principal_object_id = azuread_service_principal.vault.object_id
#   resource_object_id  = azuread_service_principal.msgraph.object_id
# }

# Grant users access to the application # Group assignment is not supported in free tier
resource "azuread_app_role_assignment" "vault_users" {
  for_each = toset([
    for user in azuread_user.users : user.object_id
  ])

  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default access role
  principal_object_id = each.value
  resource_object_id  = azuread_service_principal.vault.object_id
}

resource "vault_jwt_auth_backend" "default" {
  path               = "entra"
  type               = "oidc"
  oidc_client_id     = azuread_application.vault.client_id
  oidc_client_secret = azuread_application_password.vault.value
  default_role       = "default"
  oidc_discovery_url = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"

  tune {
    default_lease_ttl  = "6h"
    max_lease_ttl      = "24h"
    token_type         = "default-service"
    listing_visibility = "unauth"
  }
}

resource "vault_jwt_auth_backend_role" "default" {
  backend        = vault_jwt_auth_backend.default.path
  role_name      = "default"
  token_policies = ["default"]
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
    # upn   = "upn"
    # given_name = "first_name"
    # family_name  = "last_name"
  }
}

# Outputs for admin consent
output "vault_application_id" {
  value = azuread_application.vault.client_id
}