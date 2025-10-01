data "vault_policy_document" "admin" {
  rule {
    path         = "*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
}

data "vault_policy_document" "team_reader" {
  for_each = toset(["team1", "team2", "team2"])
  rule {
    path         = "${each.value}/data/*"
    capabilities = ["read", "list"]
  }
  rule {
    path         = "${each.value}/metadata/*"
    capabilities = ["read", "list"]
  }
  rule {
    path         = "${each.value}/metadata/"
    capabilities = ["list"]
  }
  rule {
    path         = "sys/mounts"
    capabilities = ["read"]
  }
}

# Create vault admin policy in root namespace
resource "vault_policy" "admin" {
  name   = "entra-admin"
  policy = data.vault_policy_document.admin.hcl
}

# Create team reader policies in their respective namespaces
resource "vault_policy" "tn001_team1_reader" {
  namespace = vault_namespace.tn001.path_fq
  name      = "entra-tn001-team1-reader"
  policy    = data.vault_policy_document.team_reader["team1"].hcl
}

resource "vault_policy" "tn001_team2_reader" {
  namespace = vault_namespace.tn001.path_fq
  name      = "entra-tn001-team2-reader"
  policy    = data.vault_policy_document.team_reader["team2"].hcl
}