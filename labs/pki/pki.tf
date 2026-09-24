# =========================================
# PKI Secrets Engine Setup
# =========================================

locals {
  pki_audit_non_hmac_request_keys = [
    "certificate", "common_name", "alt_names", "ip_sans", "uri_sans", "other_sans",
    "csr", "issuer_ref", "ttl", "not_after", "serial_number", "key_type",
    "private_key_format", "managed_key_name", "managed_key_id", "ou", "organization",
    "country", "locality", "province", "street_address", "postal_code",
    "permitted_dns_domains", "policy_identifiers", "ext_key_usage_oids",
  ]
  pki_audit_non_hmac_response_keys = ["certificate", "issuing_ca", "ca_chain", "serial_number", "error"]
}

# Enable PKI secrets engine
resource "vault_mount" "pki" {
  namespace                 = var.vault_namespace
  path                      = "pki"
  type                      = "pki"
  description               = "PKI secrets engine for intermediate CAs"
  default_lease_ttl_seconds = 3600 * 24      # 1 day
  max_lease_ttl_seconds     = 3600 * 24 * 90 # 90 days
  allowed_response_headers  = ["Link", "Location", "Replay-Nonce"]

  # Keep non-sensitive PKI fields readable in audit logs (per `vault pki health-check`)
  audit_non_hmac_request_keys  = local.pki_audit_non_hmac_request_keys
  audit_non_hmac_response_keys = local.pki_audit_non_hmac_response_keys

  # Recommended to add a prevent_destroy lifecycle rule to avoid accidental deletion
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Import certificate bundle via the import/bundle endpoint
resource "vault_generic_endpoint" "intermediate_v1" {
  namespace            = var.vault_namespace
  depends_on           = [vault_mount.pki]
  path                 = "${vault_mount.pki.path}/issuers/import/bundle"
  ignore_absent_fields = true
  disable_delete       = true
  disable_read         = true
  data_json = jsonencode({
    pem_bundle = local.intermediate_v1_bundle
  })
  write_fields = ["imported_issuers", "imported_keys"]
}

resource "vault_generic_endpoint" "intermediate_v2" {
  namespace            = var.vault_namespace
  depends_on           = [vault_mount.pki]
  path                 = "${vault_mount.pki.path}/issuers/import/bundle"
  ignore_absent_fields = true
  disable_delete       = true
  disable_read         = true
  data_json = jsonencode({
    pem_bundle = local.intermediate_v2_bundle
  })
  write_fields = ["imported_issuers", "imported_keys"]
}

# Configure v1 issuer
resource "vault_pki_secret_backend_issuer" "intermediate_v1" {
  namespace                      = var.vault_namespace
  backend                        = vault_mount.pki.path
  issuer_ref                     = jsondecode(resource.vault_generic_endpoint.intermediate_v1.write_data_json)["imported_issuers"][0]
  issuer_name                    = "intermediate-ca-v1"
  revocation_signature_algorithm = "SHA256WithRSA"
  leaf_not_after_behavior        = "err"
  usage                          = "crl-signing,issuing-certificates,read-only"
  depends_on                     = [vault_generic_endpoint.intermediate_v1]

  # Recreate the issuer when a renewed intermediate bundle is imported, so
  # issuer_ref follows the new issuer in a single apply.
  lifecycle {
    replace_triggered_by = [vault_generic_endpoint.intermediate_v1]
  }
}

# Configure v2 issuer
resource "vault_pki_secret_backend_issuer" "intermediate_v2" {
  namespace                      = var.vault_namespace
  backend                        = vault_mount.pki.path
  issuer_ref                     = jsondecode(resource.vault_generic_endpoint.intermediate_v2.write_data_json)["imported_issuers"][0]
  issuer_name                    = "intermediate-ca-v2"
  revocation_signature_algorithm = "SHA256WithRSA"
  leaf_not_after_behavior        = "err"
  usage                          = "crl-signing,issuing-certificates,read-only"
  depends_on                     = [vault_generic_endpoint.intermediate_v2]

  # Recreate the issuer when a renewed intermediate bundle is imported, so
  # issuer_ref follows the new issuer in a single apply.
  lifecycle {
    replace_triggered_by = [vault_generic_endpoint.intermediate_v2]
  }
}

# =========================================
# PKI Configuration
# =========================================

# Set default issuer (v1 initially)
resource "vault_pki_secret_backend_config_issuers" "config" {
  namespace = var.vault_namespace
  backend   = vault_mount.pki.path
  default   = vault_pki_secret_backend_issuer.intermediate_v1.issuer_id
  #default                       = vault_pki_secret_backend_issuer.intermediate_v2.issuer_id
  default_follows_latest_issuer = false
}

# Configure cluster URLs so templated AIA/CRL/OCSP values include the namespace path
resource "vault_pki_secret_backend_config_cluster" "pki_cluster_config" {
  namespace = var.vault_namespace
  backend   = vault_mount.pki.path
  path      = local.pki_url
  aia_path  = local.pki_url
}

# Configure issuer-aware URL templates for issuing certs, CRL distribution points, and OCSP
resource "vault_pki_secret_backend_config_urls" "config" {
  namespace               = var.vault_namespace
  backend                 = vault_mount.pki.path
  issuing_certificates    = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/der"]
  crl_distribution_points = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der"]
  ocsp_servers            = ["{{cluster_path}}/ocsp"]
  enable_templating       = true
  depends_on              = [vault_pki_secret_backend_config_cluster.pki_cluster_config]
}

# =========================================
# Certificate Roles
# =========================================

# certificate role for the default issuer (v1 unless changed above)
resource "vault_pki_secret_backend_role" "default" {
  namespace = var.vault_namespace
  backend   = vault_mount.pki.path
  name      = "default"
  # issuer_ref = vault_pki_secret_backend_issuer.intermediate_v1.issuer_id

  ttl     = "3600"  # 1 hour
  max_ttl = "86400" # 24 hours

  allow_ip_sans               = true
  allow_localhost             = true
  allowed_domains             = ["example.com"]
  allow_subdomains            = true
  allow_wildcard_certificates = true

  key_bits      = 4096
  key_type      = "rsa"
  key_usage     = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
  ext_key_usage = ["ServerAuth"]

  generate_lease = true
}

# Configure ACME support on the PKI mount with EAB required.
resource "vault_pki_secret_backend_config_acme" "pki_acme_config" {
  namespace                = var.vault_namespace
  backend                  = vault_mount.pki.path
  enabled                  = true
  default_directory_policy = "role:default"
  allowed_roles            = ["default"]
  allowed_issuers          = ["*"]
  eab_policy               = "always-required"
  depends_on               = [vault_pki_secret_backend_role.default]
}

# certificate role for v1 issuer
resource "vault_pki_secret_backend_role" "v1" {
  namespace  = var.vault_namespace
  backend    = vault_mount.pki.path
  name       = "v1"
  issuer_ref = vault_pki_secret_backend_issuer.intermediate_v1.issuer_id

  ttl     = "3600"  # 1 hour
  max_ttl = "86400" # 24 hours

  allow_ip_sans               = true
  allow_localhost             = true
  allowed_domains             = ["example.com"]
  allow_subdomains            = true
  allow_wildcard_certificates = true

  key_bits      = 4096
  key_type      = "rsa"
  key_usage     = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
  ext_key_usage = ["ServerAuth"]

  generate_lease = true
}

# certificate role for v2 issuer
resource "vault_pki_secret_backend_role" "v2" {
  namespace  = var.vault_namespace
  backend    = vault_mount.pki.path
  name       = "v2"
  issuer_ref = vault_pki_secret_backend_issuer.intermediate_v2.issuer_id

  ttl     = "3600"  # 1 hour
  max_ttl = "86400" # 24 hours

  allow_ip_sans               = true
  allow_localhost             = false
  allowed_domains             = ["example.com"]
  allow_subdomains            = true
  allow_wildcard_certificates = false

  key_bits      = 4096
  key_type      = "rsa"
  key_usage     = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
  ext_key_usage = ["ServerAuth"]

  generate_lease = true
}

resource "vault_pki_secret_backend_config_auto_tidy" "default" {
  namespace          = var.vault_namespace
  backend            = vault_mount.pki.path
  enabled            = true
  tidy_cert_store    = true
  tidy_revoked_certs = true
  tidy_acme          = true
  interval_duration  = "1h"
  safety_buffer      = "1h"
}
