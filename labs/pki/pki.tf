# =========================================
# PKI Secrets Engine Setup
# =========================================

# Enable PKI secrets engine
resource "vault_mount" "pki" {
  path                      = "pki"
  type                      = "pki"
  description               = "PKI secrets engine for intermediate CAs"
  default_lease_ttl_seconds = 3600 * 24      # 1 day
  max_lease_ttl_seconds     = 3600 * 24 * 90 # 90 days

  # Recommended to add a prevent_destroy lifecycle rule to avoid accidental deletion
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Import certificate bundle via the import/bundle endpoint
resource "vault_generic_endpoint" "intermediate_v1" {
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
  backend                        = vault_mount.pki.path
  issuer_ref                     = jsondecode(resource.vault_generic_endpoint.intermediate_v1.write_data_json)["imported_issuers"][0]
  issuer_name                    = "intermediate-ca-v1"
  revocation_signature_algorithm = "SHA256WithRSA"
  leaf_not_after_behavior        = "err"
  usage                          = "crl-signing,issuing-certificates,read-only"
  depends_on                     = [vault_generic_endpoint.intermediate_v1]

  # Recommended to add a prevent_destroy lifecycle rule to avoid accidental deletion
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Configure v2 issuer
resource "vault_pki_secret_backend_issuer" "intermediate_v2" {
  backend                        = vault_mount.pki.path
  issuer_ref                     = jsondecode(resource.vault_generic_endpoint.intermediate_v2.write_data_json)["imported_issuers"][0]
  issuer_name                    = "intermediate-ca-v2"
  revocation_signature_algorithm = "SHA256WithRSA"
  leaf_not_after_behavior        = "err"
  usage                          = "crl-signing,issuing-certificates,read-only"
  depends_on                     = [vault_generic_endpoint.intermediate_v2]

  # Recommended to add a prevent_destroy lifecycle rule to avoid accidental deletion
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# =========================================
# PKI Configuration
# =========================================

# Set default issuer (v1 initially)
resource "vault_pki_secret_backend_config_issuers" "config" {
  backend = vault_mount.pki.path
  default = vault_pki_secret_backend_issuer.intermediate_v1.issuer_id
  #default                       = vault_pki_secret_backend_issuer.intermediate_v2.issuer_id
  default_follows_latest_issuer = false
}

# Configure URLs for CRL and OCSP
resource "vault_pki_secret_backend_config_urls" "config" {
  backend                 = vault_mount.pki.path
  issuing_certificates    = ["https://127.0.0.1:8200/v1/pki/ca"]
  crl_distribution_points = ["https://127.0.0.1:8200/v1/pki/crl"]
  ocsp_servers            = ["https://127.0.0.1:8200/v1/pki/ocsp"]
}

# =========================================
# Certificate Roles
# =========================================

# certificate role for v1 issuer
resource "vault_pki_secret_backend_role" "default" {
  backend = vault_mount.pki.path
  name    = "default"
  # issuer_ref = vault_pki_secret_backend_issuer.intermediate_v1.issuer_id

  ttl     = "3600"  # 1 hour
  max_ttl = "86400" # 24 hours

  allow_ip_sans               = true
  allow_localhost             = true
  allowed_domains             = ["example.com", "*.example.com"]
  allow_subdomains            = true
  allow_wildcard_certificates = true

  key_bits      = 4096
  key_type      = "rsa"
  key_usage     = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
  ext_key_usage = ["ServerAuth"]

  generate_lease = true
}

# certificate role for v1 issuer
resource "vault_pki_secret_backend_role" "v1" {
  backend    = vault_mount.pki.path
  name       = "v1"
  issuer_ref = vault_pki_secret_backend_issuer.intermediate_v1.issuer_id

  ttl     = "3600"  # 1 hour
  max_ttl = "86400" # 24 hours

  allow_ip_sans               = true
  allow_localhost             = true
  allowed_domains             = ["example.com", "*.example.com"]
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
  backend    = vault_mount.pki.path
  name       = "v2"
  issuer_ref = vault_pki_secret_backend_issuer.intermediate_v2.issuer_id

  ttl     = "3600"  # 1 hour
  max_ttl = "86400" # 24 hours

  allow_ip_sans               = true
  allow_localhost             = true
  allowed_domains             = ["example.com", "*.example.com"]
  allow_subdomains            = true
  allow_wildcard_certificates = true

  key_bits      = 4096
  key_type      = "rsa"
  key_usage     = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
  ext_key_usage = ["ServerAuth"]

  generate_lease = true
}

resource "vault_pki_secret_backend_config_auto_tidy" "default" {
  backend           = vault_mount.pki.path
  enabled           = true
  tidy_cert_store   = true
  interval_duration = "1h"
  safety_buffer     = "1h"
}
