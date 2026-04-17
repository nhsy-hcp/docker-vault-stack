# Admin Policy Document
data "vault_policy_document" "admin" {
  rule {
    path         = "*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
}

# Team Reader Policy Document (reusable for multiple teams)
data "vault_policy_document" "team_reader" {
  for_each = toset(["team1", "team2"])

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

# UI Policy Document (for Vault UI access)
data "vault_policy_document" "ui" {
  # Allow access to UI internals
  rule {
    path         = "sys/internal/ui/mounts"
    capabilities = ["read"]
  }
  rule {
    path         = "sys/internal/ui/mounts/*"
    capabilities = ["read"]
  }
  rule {
    path         = "sys/internal/ui/namespaces"
    capabilities = ["read"]
  }

  # Allow access to counters for UI metrics
  rule {
    path         = "sys/internal/counters/activity"
    capabilities = ["read"]
  }
  rule {
    path         = "sys/internal/counters/config"
    capabilities = ["read"]
  }

  # # Allow reading license status
  # rule {
  #   path         = "sys/license/status"
  #   capabilities = ["read"]
  # }
  #
  # # Allow checking own token capabilities
  # rule {
  #   path         = "sys/capabilities-self"
  #   capabilities = ["update"]
  # }

  # # Namespace-aware paths (with +/ prefix for current namespace)
  # rule {
  #   path         = "+/sys/internal/ui/mounts"
  #   capabilities = ["read"]
  # }
  # rule {
  #   path         = "+/sys/internal/ui/mounts/*"
  #   capabilities = ["read"]
  # }
}

# Admin Policy (Root namespace)
resource "vault_policy" "admin" {
  name   = "authentik-admin"
  policy = data.vault_policy_document.admin.hcl
}

# Team Reader Policies (Tenant namespace)
resource "vault_policy" "tn001_team1_reader" {
  namespace = vault_namespace.tn001.path_fq
  name      = "authentik-tn001-team1-reader"
  policy    = data.vault_policy_document.team_reader["team1"].hcl
}

resource "vault_policy" "tn001_team2_reader" {
  namespace = vault_namespace.tn001.path_fq
  name      = "authentik-tn001-team2-reader"
  policy    = data.vault_policy_document.team_reader["team2"].hcl
}

# UI Policy (Tenant namespace)
resource "vault_policy" "tn001_ui" {
  namespace = vault_namespace.tn001.path_fq
  name      = "authentik-tn001-ui"
  policy    = data.vault_policy_document.ui.hcl
}
