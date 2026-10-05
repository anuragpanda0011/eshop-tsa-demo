output "acr_id" {
  value = azurerm_container_registry.main.id
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "aca_environment_id" {
  value = azurerm_container_app_environment.main.id
}

output "aca_environment_name" {
  value = azurerm_container_app_environment.main.name
}

output "aca_web_id" {
  value = azurerm_container_app.web.id
}

output "aca_web_name" {
  value = azurerm_container_app.web.name
}

output "aca_web_fqdn" {
  value = azurerm_container_app.web.ingress[0].fqdn
}

output "aca_api_id" {
  value = azurerm_container_app.api.id
}

output "aca_api_name" {
  value = azurerm_container_app.api.name
}

output "aca_api_fqdn" {
  value = azurerm_container_app.api.ingress[0].fqdn
}

output "storage_account_name" {
  value = azurerm_storage_account.dataprotection.name
}

output "storage_account_id" {
  value = azurerm_storage_account.dataprotection.id
}

output "data_protection_container_name" {
  value = azurerm_storage_container.dataprotection.name
}

output "static_web_app_url" {
  value = "https://${azurerm_static_web_app.blazoradmin.default_host_name}"
}

output "static_web_app_id" {
  value       = azurerm_static_web_app.blazoradmin.id
  description = "Resource ID of the Static Web App — AAD authentication is configured by Terraform via azurerm_static_web_app_auth_settings_v2."
}

output "apim_gateway_url" {
  value = azurerm_api_management.main.gateway_url
}

output "apim_id" {
  value = azurerm_api_management.main.id
}
