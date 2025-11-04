terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

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
