# External Group - Vault Admin (Root namespace)
resource "vault_identity_group" "vault_admin_external" {
  name     = "authentik-vault-admin-external"
  type     = "external"
  policies = [vault_policy.admin.name]

  metadata = {
    description = "External Vault Admins group from Authentik"
  }
}

resource "vault_identity_group_alias" "vault_admin_external" {
  name           = authentik_group.groups["vault-admin"].name
  mount_accessor = vault_jwt_auth_backend.root.accessor
  canonical_id   = vault_identity_group.vault_admin_external.id
}

# External Group - Team Reader (Admin namespace)
resource "vault_identity_group" "vault_tn001_team1_reader_external" {
  namespace = vault_namespace.admin.path_fq
  name      = "authentik-vault-tn001-team1-reader-external"
  type      = "external"

  metadata = {
    description = "External Vault tn001 team1 reader group from Authentik"
  }
}

resource "vault_identity_group_alias" "vault_tn001_team1_reader_external" {
  namespace      = vault_namespace.admin.path_fq
  name           = authentik_group.groups["vault-tn001-team1-reader"].name
  mount_accessor = vault_jwt_auth_backend.admin.accessor
  canonical_id   = vault_identity_group.vault_tn001_team1_reader_external.id
}

# Internal Group - Team Reader (Tenant namespace)
resource "vault_identity_group" "vault_tn001_team1_reader_internal" {
  namespace        = vault_namespace.tn001.path_fq
  name             = "authentik-vault-tn001-team1-reader-internal"
  type             = "internal"
  policies         = [vault_policy.tn001_team1_reader.name, vault_policy.tn001_ui.name]
  member_group_ids = [vault_identity_group.vault_tn001_team1_reader_external.id]
}

# External Group - Team2 Reader (Admin namespace)
resource "vault_identity_group" "vault_tn001_team2_reader_external" {
  namespace = vault_namespace.admin.path_fq
  name      = "authentik-vault-tn001-team2-reader-external"
  type      = "external"

  metadata = {
    description = "External Vault tn001 team2 reader group from Authentik"
  }
}

resource "vault_identity_group_alias" "vault_tn001_team2_reader_external" {
  namespace      = vault_namespace.admin.path_fq
  name           = authentik_group.groups["vault-tn001-team2-reader"].name
  mount_accessor = vault_jwt_auth_backend.admin.accessor
  canonical_id   = vault_identity_group.vault_tn001_team2_reader_external.id
}

# Internal Group - Team2 Reader (Tenant namespace)
resource "vault_identity_group" "vault_tn001_team2_reader_internal" {
  namespace        = vault_namespace.tn001.path_fq
  name             = "authentik-vault-tn001-team2-reader-internal"
  type             = "internal"
  policies         = [vault_policy.tn001_team2_reader.name, vault_policy.tn001_ui.name]
  member_group_ids = [vault_identity_group.vault_tn001_team2_reader_external.id]
}
