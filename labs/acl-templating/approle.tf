# ==============================================================================
# APPROLE AUTHENTICATION WITH ACL TEMPLATING DEMO
# ==============================================================================

# AppRole authentication backends (per namespace)
resource "vault_auth_backend" "approle_bu01" {
  namespace = vault_namespace.bu01.path
  type      = "approle"
  path      = "approle"
}

resource "vault_auth_backend" "approle_bu02" {
  namespace = vault_namespace.bu02.path
  type      = "approle"
  path      = "approle"
}

resource "vault_auth_backend" "approle_bu03" {
  namespace = vault_namespace.bu03.path
  type      = "approle"
  path      = "approle"
}

# AppRole roles for each business unit
resource "vault_approle_auth_backend_role" "bu01" {
  namespace      = vault_namespace.bu01.path
  backend        = vault_auth_backend.approle_bu01.path
  role_name      = "bu01-app-role"
  token_policies = ["approle-templated-policy"]

  token_ttl      = local.approle_config.token_ttl
  token_max_ttl  = local.approle_config.token_max_ttl
  bind_secret_id = local.approle_config.bind_secret_id
}

resource "vault_approle_auth_backend_role" "bu02" {
  namespace      = vault_namespace.bu02.path
  backend        = vault_auth_backend.approle_bu02.path
  role_name      = "bu02-app-role"
  token_policies = ["approle-templated-policy"]

  token_ttl      = local.approle_config.token_ttl
  token_max_ttl  = local.approle_config.token_max_ttl
  bind_secret_id = local.approle_config.bind_secret_id
}

resource "vault_approle_auth_backend_role" "bu03" {
  namespace      = vault_namespace.bu03.path
  backend        = vault_auth_backend.approle_bu03.path
  role_name      = "bu03-app-role"
  token_policies = ["approle-templated-policy"]

  token_ttl      = local.approle_config.token_ttl
  token_max_ttl  = local.approle_config.token_max_ttl
  bind_secret_id = local.approle_config.bind_secret_id
}

# AppRole secret IDs with team metadata
resource "vault_approle_auth_backend_role_secret_id" "bu01" {
  namespace = vault_namespace.bu01.path
  backend   = vault_auth_backend.approle_bu01.path
  role_name = vault_approle_auth_backend_role.bu01.role_name

  metadata = jsonencode({
    team = local.teams.team01
    env  = "dev"
  })
}

resource "vault_approle_auth_backend_role_secret_id" "bu02" {
  namespace = vault_namespace.bu02.path
  backend   = vault_auth_backend.approle_bu02.path
  role_name = vault_approle_auth_backend_role.bu02.role_name

  metadata = jsonencode({
    team = local.teams.team02
    env  = "dev"
  })
}

resource "vault_approle_auth_backend_role_secret_id" "bu03" {
  namespace = vault_namespace.bu03.path
  backend   = vault_auth_backend.approle_bu03.path
  role_name = vault_approle_auth_backend_role.bu03.role_name

  metadata = jsonencode({
    team = local.teams.team03
    env  = "dev"
  })
}

# AppRole templated policy (per namespace with specific accessor)
data "vault_policy_document" "approle_templated_policy" {
  for_each = local.approle_accessors
  rule {
    path         = "{{identity.entity.aliases.${each.value}.metadata.team}}/data/*"
    capabilities = ["read", "list"]
    description  = "Read access to team-specific secrets using ACL templating"
  }

  rule {
    path         = "{{identity.entity.aliases.${each.value}.metadata.team}}/metadata"
    capabilities = ["read", "list"]
  }

  rule {
    path         = "{{identity.entity.aliases.${each.value}.metadata.team}}/metadata/*"
    capabilities = ["read"]
  }

  rule {
    path         = "shared/data/{{identity.entity.aliases.${each.value}.metadata.team}}/*"
    capabilities = ["read", "list"]
  }

  rule {
    path         = "shared/metadata/{{identity.entity.aliases.${each.value}.metadata.team}}"
    capabilities = ["read", "list"]
  }

  rule {
    path         = "shared/metadata/{{identity.entity.aliases.${each.value}.metadata.team}}/*"
    capabilities = ["read"]
  }
}

# Apply AppRole policies to each namespace
resource "vault_policy" "templated_policy_bu01" {
  namespace = vault_namespace.bu01.path
  name      = "approle-templated-policy"
  policy    = data.vault_policy_document.approle_templated_policy["bu01"].hcl
}

resource "vault_policy" "templated_policy_bu02" {
  namespace = vault_namespace.bu02.path
  name      = "approle-templated-policy"
  policy    = data.vault_policy_document.approle_templated_policy["bu02"].hcl
}

resource "vault_policy" "templated_policy_bu03" {
  namespace = vault_namespace.bu03.path
  name      = "approle-templated-policy"
  policy    = data.vault_policy_document.approle_templated_policy["bu03"].hcl
}