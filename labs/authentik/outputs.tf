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
