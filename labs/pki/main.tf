
locals {
  # Create PEM bundle for intermediate v1 (cert + key)
  intermediate_v1_bundle = "${tls_locally_signed_cert.intermediate_v1.cert_pem}${tls_private_key.intermediate_v1.private_key_pem}"

  # Create PEM bundle for intermediate v2
  intermediate_v2_bundle = "${tls_locally_signed_cert.intermediate_v2.cert_pem}${tls_private_key.intermediate_v2.private_key_pem}"
}