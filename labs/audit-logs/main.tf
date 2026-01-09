resource "vault_audit" "vault-benchmark" {
  type = "file"
  path = "vault_benchmark"

  options = {
    file_path = "/vault/logs/audit_vault_benchmark.log"
  }
  # namespace = "vault-benchmark"
}


# https://developer.hashicorp.com/vault/docs/enterprise/audit/filtering

resource "vault_audit" "vault-benchmark_filter" {
  type = "file"
  path = "vault_benchmark_filter"
  options = {
    file_path = "/vault/logs/audit_vault_benchmark_filter.log"
    filter    = "namespace == \"vault-benchmark/\""
  }
}