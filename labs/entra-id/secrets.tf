# KV v2 secrets engine mount in tn001 namespace
resource "vault_mount" "kv_tn001_team1" {
  namespace   = vault_namespace.tn001.path_fq
  path        = "team1"
  type        = "kv-v2"
  description = "KV v2 secrets engine for tn001 namespace"
}

# Dummy secret in tn001 namespace
resource "vault_kv_secret_v2" "kv_tn001_team1_dummy" {
  namespace           = vault_namespace.tn001.path_fq
  mount               = vault_mount.kv_tn001_team1.path
  name                = "dummy-app"
  cas                 = 1
  delete_all_versions = true

  data_json = jsonencode({
    username = "dummy-user"
    password = "dummy-password-123"
    api_key  = "dummy-api-key-xyz789"
  })
}