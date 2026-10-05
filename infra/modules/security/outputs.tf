output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "managed_identity_web_id" {
  value = azurerm_user_assigned_identity.web.id
}

output "managed_identity_api_id" {
  value = azurerm_user_assigned_identity.api.id
}

output "managed_identity_apim_id" {
  value       = azurerm_user_assigned_identity.apim.id
  description = "Resource ID of the dedicated APIM managed identity."
}

output "managed_identity_apim_principal_id" {
  value       = azurerm_user_assigned_identity.apim.principal_id
  description = "Principal ID of the dedicated APIM managed identity."
}

output "managed_identity_apim_client_id" {
  value       = azurerm_user_assigned_identity.apim.client_id
  description = "Client ID of the dedicated APIM managed identity."
}

output "managed_identity_acr_pull_id" {
  value = azurerm_user_assigned_identity.acr_pull.id
}

output "managed_identity_web_client_id" {
  value = azurerm_user_assigned_identity.web.client_id
}

output "managed_identity_api_client_id" {
  value = azurerm_user_assigned_identity.api.client_id
}

output "managed_identity_acr_pull_client_id" {
  value = azurerm_user_assigned_identity.acr_pull.client_id
}

output "managed_identity_web_principal_id" {
  value = azurerm_user_assigned_identity.web.principal_id
}

output "managed_identity_api_principal_id" {
  value = azurerm_user_assigned_identity.api.principal_id
}

output "managed_identity_acr_pull_principal_id" {
  value = azurerm_user_assigned_identity.acr_pull.principal_id
}

output "data_protection_key_id" {
  value = azurerm_key_vault_key.data_protection.id
}

output "data_protection_key_name" {
  value = azurerm_key_vault_key.data_protection.name
}

output "jwt_secret_key_secret_name" {
  value = azurerm_key_vault_secret.jwt_secret_key.name
}

output "audit_storage_account_id" {
  value = azurerm_storage_account.audit.id
}

output "audit_storage_primary_blob_endpoint" {
  value = azurerm_storage_account.audit.primary_blob_endpoint
}
