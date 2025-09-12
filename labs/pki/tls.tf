# =========================================
# Root CA Generation
# =========================================

# Generate Root CA private key
resource "tls_private_key" "root_ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create self signed Root CA certificate
resource "tls_self_signed_cert" "root_ca" {
  private_key_pem = tls_private_key.root_ca.private_key_pem

  subject {
    organization = var.organization_name
    common_name  = "My Root CA"
  }

  validity_period_hours = 24 * 365 # 1 year
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "key_encipherment",
    "digital_signature"
  ]
}

# =========================================
# Intermediate CA v1
# =========================================

# Generate intermediate v1 private key
resource "tls_private_key" "intermediate_v1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create intermediate v1 CSR
resource "tls_cert_request" "intermediate_v1" {
  private_key_pem = tls_private_key.intermediate_v1.private_key_pem
  subject {
    organization = var.organization_name
    common_name  = "My Intermediate CA v1"
  }
}

# Sign intermediate v1 CSR with root CA
resource "tls_locally_signed_cert" "intermediate_v1" {
  cert_request_pem   = tls_cert_request.intermediate_v1.cert_request_pem
  ca_private_key_pem = tls_private_key.root_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca.cert_pem

  validity_period_hours = 24 * 90 # 90 days
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "key_encipherment",
    "digital_signature"
  ]
}

# =========================================
# Intermediate CA v2
# =========================================

# Generate intermediate v2 private key
resource "tls_private_key" "intermediate_v2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create intermediate v2 CSR
resource "tls_cert_request" "intermediate_v2" {
  private_key_pem = tls_private_key.intermediate_v2.private_key_pem
  subject {
    organization = var.organization_name
    common_name  = "My Intermediate CA v2"
  }
}

# Sign intermediate v2 CSR with root CA
resource "tls_locally_signed_cert" "intermediate_v2" {
  cert_request_pem   = tls_cert_request.intermediate_v2.cert_request_pem
  ca_private_key_pem = tls_private_key.root_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca.cert_pem

  validity_period_hours = 24 * 90 # 90 days
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "key_encipherment",
    "digital_signature"
  ]
}

resource "null_resource" "root_ca" {
  triggers = {
    always_run = md5(tls_self_signed_cert.root_ca.cert_pem)
  }

  provisioner "local-exec" {
    command = "echo '${tls_self_signed_cert.root_ca.cert_pem}' | openssl x509 -noout -text"
  }
}

resource "null_resource" "intermediate_v1" {
  triggers = {
    always_run = md5(tls_locally_signed_cert.intermediate_v1.cert_pem)
  }

  provisioner "local-exec" {
    command = "echo '${tls_locally_signed_cert.intermediate_v1.cert_pem}' | openssl x509 -noout -text"
  }
  depends_on = [null_resource.root_ca]
}

resource "null_resource" "intermediate_v2" {
  triggers = {
    always_run = md5(tls_locally_signed_cert.intermediate_v2.cert_pem)
  }
  provisioner "local-exec" {
    command = "echo '${tls_locally_signed_cert.intermediate_v2.cert_pem}' | openssl x509 -noout -text"
  }
  depends_on = [null_resource.intermediate_v1]
}

# resource "local_sensitive_file" "root_ca_key" {
#   content  = tls_private_key.root_ca.private_key_pem
#   filename = "certs/root-ca.key"
# }

resource "local_file" "root_ca_cert" {
  content  = tls_self_signed_cert.root_ca.cert_pem
  filename = "certs/root-ca.pem"
}

# resource "local_sensitive_file" "intermediate_v1_key" {
#   content  = tls_private_key.intermediate_v1.private_key_pem
#   filename = "certs/intermediate-v1.key"
# }

resource "local_file" "intermediate_v1_cert" {
  content  = tls_locally_signed_cert.intermediate_v1.cert_pem
  filename = "certs/intermediate-v1.pem"
}

# resource "local_sensitive_file" "intermediate_v2_key" {
#   content  = tls_private_key.intermediate_v2.private_key_pem
#   filename = "certs/intermediate-v2.key"
# }

resource "local_file" "intermediate_v2_cert" {
  content  = tls_locally_signed_cert.intermediate_v2.cert_pem
  filename = "certs/intermediate-v2.pem"
}