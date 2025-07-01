# ==============================================================================
# OUTPUTS
# ==============================================================================

# AppRole demo outputs
output "app_role_ids" {
  description = "AppRole role IDs for each business unit"
  value = {
    bu01 = vault_approle_auth_backend_role.bu01.role_id
    bu02 = vault_approle_auth_backend_role.bu02.role_id
    bu03 = vault_approle_auth_backend_role.bu03.role_id
  }
}

output "app_secret_ids" {
  description = "AppRole secret IDs for each business unit"
  value = {
    bu01 = vault_approle_auth_backend_role_secret_id.bu01.secret_id
    bu02 = vault_approle_auth_backend_role_secret_id.bu02.secret_id
    bu03 = vault_approle_auth_backend_role_secret_id.bu03.secret_id
  }
  sensitive = true
}

# Userpass demo outputs
output "userpass_user_entity_ids" {
  description = "Entity IDs for userpass demo users"
  value = {
    for name, entity in vault_identity_entity.userpass_users : name => entity.id
  }
}

output "userpass_group_ids" {
  description = "Identity group IDs for team groups"
  value = {
    team1 = vault_identity_group.team1_group.id
    team2 = vault_identity_group.team2_group.id
    team3 = vault_identity_group.team3_group.id
  }
}

output "userpass_accessor" {
  description = "Userpass auth backend accessor"
  value       = vault_auth_backend.userpass.accessor
}

output "userpass_demo_credentials" {
  description = "Demo user credentials for testing"
  value = {
    for name, user in local.userpass_users : name => {
      username  = name
      password  = user.password
      namespace = user.namespace
    }
  }
  sensitive = true
}