# Authentik OIDC Integration with HashiCorp Vault
#
# This lab demonstrates how to integrate Authentik as an OIDC provider
# for HashiCorp Vault authentication across multiple namespaces.
#
# Architecture:
# - Root namespace: vault-admin group with full access
# - Admin namespace: vault-user group with standard access
# - Tenant namespace (tn001): vault-tn001-team1-reader group with read-only access
#
# Resources are organized across multiple files:
# - authentik.tf: Authentik provider, application, groups, and users
# - vault.tf: Vault namespaces and OIDC auth configuration
# - identity.tf: Vault identity groups and aliases
# - policies.tf: Vault policies for access control
# - secrets.tf: Sample KV secrets for testing
