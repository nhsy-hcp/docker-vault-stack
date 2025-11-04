provider "aws" {
  region = var.aws_region
}

provider "vault" {
  # Uses environment variables:
  # VAULT_ADDR, VAULT_TOKEN, VAULT_CACERT
}

provider "vault" {
  alias     = "tn001"
  namespace = "admin/tn001"
}
