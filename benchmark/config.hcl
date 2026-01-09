# Basic Benchmark config options
#vault_addr = ""    # set via ENVIRONMENT VARIABLE
#vault_token = ""   # set via ENVIRONMENT VARIABLE
vault_namespace="vault-benchmark"
duration = "15m"
cleanup = true

#test "pki_issue" "pki_issue_test1" {
#  weight = 25
#  config {
#      setup_delay="2s"
#      root_ca {
#        common_name = "benchmark.test"
#      }
#      intermediate_csr {
#        common_name = "benchmark.test Intermediate Authority"
#      }
#      role {
#        ttl = "20m"
#        key_type = "ed25519"
#      }
#  }
#}

test "approle_auth" "approle_logins_1" {
  weight = 20
  config {
    role {
      role_name = "benchmark-role-1"
      token_ttl="5m"
    }
  }
}

test "approle_auth" "approle_logins_2" {
  weight = 20
  config {
    role {
      role_name = "benchmark-role-3"
      token_ttl="15m"
    }
  }
}

test "userpass_auth" "userpass_test1" {
    weight = 20
    config {
        username = "test-user"
        password = "password"
        token_ttl = "5m"
    }
}

test "userpass_auth" "userpass_test2" {
    weight = 20
    config {
        username = "test-user2"
        password = "password"
        token_ttl = "10m"
    }
}

# test "kvv2_write" "static_secret_writes" {
#  weight = 20
#  config {
#    numkvs = 100
#    kvsize = 100
#  }
# }

test "kvv2_read" "static_secret_reads" {
 weight = 20
 config {
   numkvs = 100
#    kvsize = 100
 }
}

#test "ssh_sign" "ssh_sign_test1" {
#  weight = 25
#  config {
#    role {
#      allow_user_certificates = true
#    }
#    key_signing {
#      ttl = "5m"
#    }
#  }
#}

#test "seal_status" "seal_status_test_1" {
#    weight = 25
#}
#
# test "pki_issue" "pki_issue_test1" {
#   weight = 50
#   config {
#       setup_delay="2s"
#       root_ca {
#         common_name = "benchmark.test"
#       }
#       intermediate_csr {
#         common_name = "benchmark.test Intermediate Authority"
#       }
#       role {
#         ttl = "1h"
#         key_type = "ed25519"
#       }
#   }
# }
#
# test "pki_issue" "pki_issue_test2" {
#   weight = 100
#   config {
#       setup_delay="2s"
#       root_ca {
#         common_name = "benchmark.test2"
#       }
#       intermediate_csr {
#         common_name = "benchmark.test2 Intermediate Authority"
#       }
#       role {
#         ttl = "1h"
#         key_type = "rsa"
#         key_bits = 2048
#       }
#   }
# }

# test "pki_issue" "pki_issue_test3" {
#   weight = 100
#   config {
#       setup_delay="2s"
#       root_ca {
#         common_name = "benchmark.test3"
#       }
#       intermediate_csr {
#         common_name = "benchmark.test3 Intermediate Authority"
#       }
#       role {
#         ttl = "1h"
#         key_type = "rsa"
#         key_bits = 4096
#       }
#   }
# }