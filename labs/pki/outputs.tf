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
#
output "intermediate_v1_issuer_id" {
  description = "Intermediate CA v1 issuer ID"
  value       = vault_pki_secret_backend_issuer.intermediate_v1.issuer_id
}

output "intermediate_v2_issuer_id" {
  description = "Intermediate CA v2 issuer ID"
  value       = vault_pki_secret_backend_issuer.intermediate_v2.issuer_id
}

# output "certificate_roles" {
#   description = "Available certificate roles"
#   value = {
#     server_v1 = vault_pki_secret_backend_role.server_cert_v1.name
#     server_v2 = vault_pki_secret_backend_role.server_cert_v2.name
#     client_v2 = vault_pki_secret_backend_role.client_cert_v2.name
#   }
# }
#
# output "certificate_endpoints" {
#   description = "Certificate issuance endpoints"
#   value = {
#     server_v1 = "${vault_mount.pki.path}/issue/${vault_pki_secret_backend_role.server_cert_v1.name}"
#     server_v2 = "${vault_mount.pki.path}/issue/${vault_pki_secret_backend_role.server_cert_v2.name}"
#     client_v2 = "${vault_mount.pki.path}/issue/${vault_pki_secret_backend_role.client_cert_v2.name}"
#   }
# }