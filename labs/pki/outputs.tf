output "pki_mount_path" {
  description = "PKI mount path"
  value       = vault_mount.pki.path
}

output "root_certificate_pem" {
  description = "Root CA certificate (for distribution)"
  value       = tls_self_signed_cert.root_ca.cert_pem
  sensitive   = true
}

output "intermediate_v1_certificate_pem" {
  description = "Intermediate CA v1 certificate (for distribution)"
  value       = tls_locally_signed_cert.intermediate_v1.cert_pem
  sensitive   = true
}

output "intermediate_v2_certificate_pem" {
  description = "Intermediate CA v2 certificate (for distribution)"
  value       = tls_locally_signed_cert.intermediate_v2.cert_pem
  sensitive   = true
}

output "intermediate_v1_issuer_id" {
  description = "Intermediate CA v1 issuer ID"
  value       = vault_pki_secret_backend_issuer.intermediate_v1.issuer_id
}

output "intermediate_v2_issuer_id" {
  description = "Intermediate CA v2 issuer ID"
  value       = vault_pki_secret_backend_issuer.intermediate_v2.issuer_id
}

output "certificate_roles" {
  description = "Certificate roles and their issue endpoints"
  value = {
    for k, r in {
      default = vault_pki_secret_backend_role.default
      v1      = vault_pki_secret_backend_role.v1
      v2      = vault_pki_secret_backend_role.v2
    } : k => "${var.vault_namespace}/${vault_mount.pki.path}/issue/${r.name}"
  }
}

output "acme_directory" {
  description = "ACME directory URL (EAB required)"
  value       = "${local.pki_url}/acme/directory"
}
