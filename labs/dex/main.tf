locals {
  redirect_uris = [
    "http://127.0.0.1:8250/oidc/callback",
    "http://localhost:8250/oidc/callback",
    "http://vault.localhost:8250/oidc/callback",
    "http://vault.localhost:8200/ui/vault/auth/${var.vault_oidc_mount_path}/oidc/callback",
  ]
}
