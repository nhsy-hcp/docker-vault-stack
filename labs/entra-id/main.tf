locals {
  redirect_uris = [
    "http://localhost:8250/oidc/callback",
    "https://127.0.0.1:8200/ui/vault/auth/azure/oidc/callback",
    "https://localhost:8200/ui/vault/auth/azure/oidc/callback",
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
    # id_token {
    #   name = "given_name"
    # }
    # id_token {
    #   name = "family_name"
    # }
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
    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["openid"]
      type = "Scope"
    }
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
  for_each = var.azure_users

  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default access role
  principal_object_id = azuread_user.users[each.key].object_id
  resource_object_id  = azuread_service_principal.vault.object_id
}
