# Enable KV Engine (Tenant namespace)
resource "vault_mount" "kv" {
  namespace = vault_namespace.tn001.path_fq
  path      = "team1"
  type      = "kv-v2"
}

# Create Sample Secrets
resource "vault_kv_secret_v2" "app1" {
  namespace = vault_namespace.tn001.path_fq
  mount     = vault_mount.kv.path
  name      = "app1"

  data_json = jsonencode({
    username = "app1-user"
    password = "app1-password"
  })
}

resource "vault_kv_secret_v2" "app2" {
  namespace = vault_namespace.tn001.path_fq
  mount     = vault_mount.kv.path
  name      = "app2"

  data_json = jsonencode({
    username = "app2-user"
    password = "app2-password"
  })
}

# Enable KV Engine for Team2 (Tenant namespace)
resource "vault_mount" "kv_team2" {
  namespace = vault_namespace.tn001.path_fq
  path      = "team2"
  type      = "kv-v2"
}

# Create Sample Secrets for Team2
resource "vault_kv_secret_v2" "team2_app1" {
  namespace = vault_namespace.tn001.path_fq
  mount     = vault_mount.kv_team2.path
  name      = "app1"

  data_json = jsonencode({
    username = "team2-app1-user"
    password = "team2-app1-password"
  })
}
