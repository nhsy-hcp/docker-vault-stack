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
  mount_accessor = vault_jwt_auth_backend.default.accessor
  canonical_id   = vault_identity_group.vault_admin_external.id
}

resource "vault_identity_group" "vault_bu01_reader_external" {
  name = "entra-vault-bu01-reader-external"
  type = "external"
  policies = [
    vault_policy.bu01_reader.name,
  ]
  metadata = {
    description = "External Vault BU01 reader group from Entra ID"
  }
}

resource "vault_identity_group_alias" "vault_bu01_reader_external" {
  name           = azuread_group.groups["vault-bu01-reader"].object_id
  mount_accessor = vault_jwt_auth_backend.default.accessor
  canonical_id   = vault_identity_group.vault_bu01_reader_external.id
}

resource "vault_identity_group" "vault_bu01_reader_internal" {
  namespace = "bu01"
  name      = "entra-vault-bu01-reader-internal"
  type      = "internal"
  policies = [
    vault_policy.bu01_reader.name,
  ]
  member_group_ids = [vault_identity_group.vault_bu01_reader_external.id]
}