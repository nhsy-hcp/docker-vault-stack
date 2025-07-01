# ==============================================================================
# USERPASS AUTHENTICATION WITH NAMESPACE-LINKED GROUPS DEMO
# ==============================================================================

# Userpass authentication backend (root namespace)
resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = "userpass"
}

# Create userpass users in root namespace
resource "vault_generic_endpoint" "userpass_users" {
  for_each = local.userpass_users

  path                 = "auth/userpass/users/${each.key}"
  ignore_absent_fields = true

  data_json = jsonencode({
    password = each.value.password
  })

  depends_on = [vault_auth_backend.userpass]
}

# Create identity entities for users in root namespace (no metadata)
resource "vault_identity_entity" "userpass_users" {
  for_each = local.userpass_users

  name = each.key
}

# Create entity aliases linking users to userpass auth
resource "vault_identity_entity_alias" "userpass_users" {
  for_each = local.userpass_users

  name           = each.key
  mount_accessor = vault_auth_backend.userpass.accessor
  canonical_id   = vault_identity_entity.userpass_users[each.key].id
}

# Create team-named identity groups for ACL templating
resource "vault_identity_group" "team1_group" {
  namespace = vault_namespace.bu01.path
  name      = "team1-group"
  type      = "internal"

  member_entity_ids = [
    for user, config in local.userpass_users :
    vault_identity_entity.userpass_users[user].id
    if config.namespace == "bu01"
  ]

  metadata = {
    id = "team1"
  }

  policies = ["group-templated-policy"]
}

resource "vault_identity_group" "team2_group" {
  namespace = vault_namespace.bu02.path
  name      = "team2-group"
  type      = "internal"

  member_entity_ids = [
    for user, config in local.userpass_users :
    vault_identity_entity.userpass_users[user].id
    if config.namespace == "bu02"
  ]

  metadata = {
    id = "team2"
  }

  policies = ["group-templated-policy"]
}

resource "vault_identity_group" "team3_group" {
  namespace = vault_namespace.bu03.path
  name      = "team3-group"
  type      = "internal"

  member_entity_ids = [
    for user, config in local.userpass_users :
    vault_identity_entity.userpass_users[user].id
    if config.namespace == "bu03"
  ]

  metadata = {
    id = "team3"
  }

  policies = ["group-templated-policy"]
}

# Namespace-specific templated policies using correct group metadata syntax

# BU01 policy for team1-group
data "vault_policy_document" "group_templated_policy_bu01" {
  # Access to team secrets based on group metadata using correct ACL templating
  rule {
    path         = "{{identity.groups.names.team1-group.metadata.id}}/data/*"
    capabilities = ["create", "read", "update", "delete", "list"]
    description  = "Access to team secrets based on team1-group metadata"
  }

  rule {
    path         = "{{identity.groups.names.team1-group.metadata.id}}/metadata"
    capabilities = ["read", "list"]
  }

  rule {
    path         = "{{identity.groups.names.team1-group.metadata.id}}/metadata/*"
    capabilities = ["read"]
  }

  # Access to shared team secrets using group metadata templating
  rule {
    path         = "shared/data/{{identity.groups.names.team1-group.metadata.id}}/*"
    capabilities = ["read", "list"]
    description  = "Read access to shared team secrets based on team1-group metadata"
  }

  rule {
    path         = "shared/metadata/{{identity.groups.names.team1-group.metadata.id}}"
    capabilities = ["read", "list"]
  }

  rule {
    path         = "shared/metadata/{{identity.groups.names.team1-group.metadata.id}}/*"
    capabilities = ["read"]
  }

  # Entity self-management using ACL templating
  rule {
    path         = "identity/entity/id/{{identity.entity.id}}"
    capabilities = ["read", "update"]
    description  = "Users can manage their own entity metadata"
  }
}

# BU02 policy for team2-group
data "vault_policy_document" "group_templated_policy_bu02" {
  # Access to team secrets based on group metadata using correct ACL templating
  rule {
    path         = "{{identity.groups.names.team2-group.metadata.id}}/data/*"
    capabilities = ["create", "read", "update", "delete", "list"]
    description  = "Access to team secrets based on team2-group metadata"
  }

  rule {
    path         = "{{identity.groups.names.team2-group.metadata.id}}/metadata"
    capabilities = ["read", "list"]
  }

  rule {
    path         = "{{identity.groups.names.team2-group.metadata.id}}/metadata/*"
    capabilities = ["read"]
  }

  # Access to shared team secrets using group metadata templating
  rule {
    path         = "shared/data/{{identity.groups.names.team2-group.metadata.id}}/*"
    capabilities = ["read", "list"]
    description  = "Read access to shared team secrets based on team2-group metadata"
  }

  rule {
    path         = "shared/metadata/{{identity.groups.names.team2-group.metadata.id}}"
    capabilities = ["read", "list"]
  }

  rule {
    path         = "shared/metadata/{{identity.groups.names.team2-group.metadata.id}}/*"
    capabilities = ["read"]
  }

  # Entity self-management using ACL templating
  rule {
    path         = "identity/entity/id/{{identity.entity.id}}"
    capabilities = ["read", "update"]
    description  = "Users can manage their own entity metadata"
  }
}

# BU03 policy for team3-group
data "vault_policy_document" "group_templated_policy_bu03" {
  # Access to team secrets based on group metadata using correct ACL templating
  rule {
    path         = "{{identity.groups.names.team3-group.metadata.id}}/data/*"
    capabilities = ["create", "read", "update", "delete", "list"]
    description  = "Access to team secrets based on team3-group metadata"
  }

  rule {
    path         = "{{identity.groups.names.team3-group.metadata.id}}/metadata"
    capabilities = ["read", "list"]
  }

  rule {
    path         = "{{identity.groups.names.team3-group.metadata.id}}/metadata/*"
    capabilities = ["read"]
  }

  # Access to shared team secrets using group metadata templating
  rule {
    path         = "shared/data/{{identity.groups.names.team3-group.metadata.id}}/*"
    capabilities = ["read", "list"]
    description  = "Read access to shared team secrets based on team3-group metadata"
  }

  rule {
    path         = "shared/metadata/{{identity.groups.names.team3-group.metadata.id}}"
    capabilities = ["read", "list"]
  }

  rule {
    path         = "shared/metadata/{{identity.groups.names.team3-group.metadata.id}}/*"
    capabilities = ["read"]
  }

  # Entity self-management using ACL templating
  rule {
    path         = "identity/entity/id/{{identity.entity.id}}"
    capabilities = ["read", "update"]
    description  = "Users can manage their own entity metadata"
  }
}

# Apply namespace-specific templated policies
resource "vault_policy" "group_templated_policy_bu01" {
  namespace = vault_namespace.bu01.path
  name      = "group-templated-policy"
  policy    = data.vault_policy_document.group_templated_policy_bu01.hcl
}

resource "vault_policy" "group_templated_policy_bu02" {
  namespace = vault_namespace.bu02.path
  name      = "group-templated-policy"
  policy    = data.vault_policy_document.group_templated_policy_bu02.hcl
}

resource "vault_policy" "group_templated_policy_bu03" {
  namespace = vault_namespace.bu03.path
  name      = "group-templated-policy"
  policy    = data.vault_policy_document.group_templated_policy_bu03.hcl
}