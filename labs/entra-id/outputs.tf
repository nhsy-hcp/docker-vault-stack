# Outputs for admin consent
output "vault_application_id" {
  value = azuread_application.vault.client_id
}