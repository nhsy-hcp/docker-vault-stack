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

resource "vault_policy" "admin" {
  name   = "entra-admin"
  policy = data.vault_policy_document.admin.hcl
}

resource "vault_policy" "bu01_reader" {
  namespace = "bu01"
  name      = "entra-bu01-reader"
  policy    = data.vault_policy_document.team_reader["team1"].hcl
}