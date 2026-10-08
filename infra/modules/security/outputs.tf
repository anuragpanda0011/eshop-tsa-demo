output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.main.name
}

output "web_managed_identity_id" {
  description = "Resource ID of the Web user-assigned managed identity."
  value       = azurerm_user_assigned_identity.web.id
}

output "web_managed_identity_client_id" {
  description = "Client ID of the Web user-assigned managed identity."
  value       = azurerm_user_assigned_identity.web.client_id
}

output "web_managed_identity_principal_id" {
  description = "Principal ID of the Web user-assigned managed identity."
  value       = azurerm_user_assigned_identity.web.principal_id
}

output "api_managed_identity_id" {
  description = "Resource ID of the API user-assigned managed identity."
  value       = azurerm_user_assigned_identity.api.id
}

output "api_managed_identity_client_id" {
  description = "Client ID of the API user-assigned managed identity."
  value       = azurerm_user_assigned_identity.api.client_id
}

output "api_managed_identity_principal_id" {
  description = "Principal ID of the API user-assigned managed identity."
  value       = azurerm_user_assigned_identity.api.principal_id
}

output "cicd_managed_identity_id" {
  description = "Resource ID of the CI/CD user-assigned managed identity."
  value       = azurerm_user_assigned_identity.cicd.id
}

output "cicd_managed_identity_client_id" {
  description = "Client ID of the CI/CD user-assigned managed identity."
  value       = azurerm_user_assigned_identity.cicd.client_id
}

output "cicd_service_principal_client_id" {
  description = "Client ID of the CI/CD service principal (for OIDC)."
  value       = azuread_application.cicd.client_id
}

output "cicd_service_principal_object_id" {
  description = "Object ID of the CI/CD service principal (for role assignments)."
  value       = azuread_service_principal.cicd.object_id
}

output "storage_account_id" {
  description = "Resource ID of the data-protection storage account."
  value       = azurerm_storage_account.data_protection.id
}

output "storage_account_name" {
  description = "Name of the data-protection storage account."
  value       = azurerm_storage_account.data_protection.name
}

output "storage_container_name" {
  description = "Name of the data-protection blob container."
  value       = azurerm_storage_container.data_protection.name
}

output "jwt_secret_key_value" {
  description = "JWT secret key value (sensitive — sourced from input variable, stored in Key Vault)."
  value       = var.jwt_secret_key_value
  sensitive   = true
}

output "storage_cmk_key_id" {
  description = "Resource ID of the storage CMK Key Vault key."
  value       = azurerm_key_vault_key.storage_cmk.id
}

output "data_protection_key_id" {
  description = "Resource ID of the Data Protection ring Key Vault key."
  value       = azurerm_key_vault_key.data_protection.id
}
