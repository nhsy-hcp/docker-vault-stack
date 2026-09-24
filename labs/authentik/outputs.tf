output "authentik_url" {
  value       = "http://authentik.localhost:9000"
  description = "Authentik server URL (from AUTHENTIK_URL environment variable)"
}

output "authentik_client_id" {
  value       = authentik_provider_oauth2.vault.client_id
  description = "OAuth2 client ID for Vault"
}

output "authentik_client_secret" {
  value       = authentik_provider_oauth2.vault.client_secret
  description = "OAuth2 client secret for Vault"
  sensitive   = true
}

output "vault_oidc_mount_path" {
  value       = var.vault_oidc_mount_path
  description = "Vault OIDC mount path"
}

output "authentik_groups" {
  value = {
    for k, v in authentik_group.groups : k => {
      id   = v.id
      name = v.name
    }
  }
  description = "Created Authentik groups"
}

output "vault_namespaces" {
  value = {
    admin = vault_namespace.admin.path_fq
    tn001 = vault_namespace.tn001.path_fq
  }
  description = "Vault namespaces"
}

output "test_users" {
  value = {
    for k, v in authentik_user.users : k => {
      email  = v.email
      groups = v.groups
    }
  }
  description = "Created test users"
}

output "authentik_end_session_endpoint" {
  value       = "http://authentik.localhost:9000/application/o/${authentik_application.vault.slug}/end-session/"
  description = "Authentik end-session endpoint URL for logout"
}

output "scim_enabled" {
  value       = var.enable_scim
  description = "Whether SCIM provisioning is enabled"
}

output "scim_endpoint" {
  value       = var.enable_scim ? "${var.vault_scim_addr}/v1/identity/scim/v2" : null
  description = "Vault SCIM endpoint URLs (internal Docker addresses)"
}

output "authentik_scim_provider_id" {
  value       = var.enable_scim ? authentik_provider_scim.vault[0].id : null
  description = "Authentik SCIM provider ID"
}

output "scim_bearer_token" {
  value       = var.enable_scim ? local.scim_token : null
  sensitive   = true
  description = "Vault SCIM bearer token"
}

output "scim_entity_alias_id" {
  value       = var.enable_scim ? vault_identity_entity_alias.scim[0].id : null
  description = "Vault identity entity alias ID"
}

output "scim_entity_alias_name" {
  value       = var.enable_scim ? vault_identity_entity_alias.scim[0].name : null
  description = "Vault identity entity alias name"
}
