# Create Vault identity groups and group aliases for Vault Admin Entra ID group
resource "vault_identity_group" "vault_admin_external" {
  name = "entra-vault-admin-external"
  type = "external"
  policies = [
    vault_policy.admin.name,
  ]
  metadata = {
    description = "External Vault Admins group from Entra ID"
  }
}

resource "vault_identity_group_alias" "vault_admin_external" {
  name           = azuread_group.groups["vault-admin"].object_id
  mount_accessor = vault_jwt_auth_backend.root.accessor
  canonical_id   = vault_identity_group.vault_admin_external.id
}

# Create Vault identity groups and group aliases for Vault tn001 team1 Entra ID group
resource "vault_identity_group" "vault_tn001_team1_reader_external" {
  namespace = vault_namespace.admin.path_fq
  name      = "entra-vault-tn001-team1-reader-external"
  type      = "external"
  metadata = {
    description = "External Vault tn001 team1 reader group from Entra ID"
  }
}

resource "vault_identity_group_alias" "vault_tn001_team1_reader_external" {
  namespace      = vault_namespace.admin.path_fq
  name           = azuread_group.groups["vault-tn001-team1-reader"].object_id
  mount_accessor = vault_jwt_auth_backend.admin.accessor
  canonical_id   = vault_identity_group.vault_tn001_team1_reader_external.id
}

resource "vault_identity_group" "vault_tn001_team_1_reader_internal" {
  namespace = vault_namespace.tn001.path_fq
  name      = "entra-vault-tn001-team1-reader-internal"
  type      = "internal"
  policies = [
    vault_policy.tn001_team1_reader.name,
  ]
  member_group_ids = [vault_identity_group.vault_tn001_team1_reader_external.id]
}