terraform {
  required_version = ">= 1.5"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.9.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.4.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.12.0"
    }
  }
}

locals {
  # Create PEM bundle for intermediate v1 (cert + key)
  intermediate_v1_bundle = "${tls_locally_signed_cert.intermediate_v1.cert_pem}${tls_private_key.intermediate_v1.private_key_pem}"

  # Create PEM bundle for intermediate v2
  intermediate_v2_bundle = "${tls_locally_signed_cert.intermediate_v2.cert_pem}${tls_private_key.intermediate_v2.private_key_pem}"

  # Base URL of the PKI mount, including the namespace path
  pki_url = "${var.vault_cluster_addr}/v1/${var.vault_namespace}/${vault_mount.pki.path}"
}
