output "acr_id" {
  description = "Resource ID of the Azure Container Registry."
  value       = azurerm_container_registry.main.id
}

output "acr_login_server" {
  description = "Login server URL of the Azure Container Registry."
  value       = azurerm_container_registry.main.login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.main.name
}

output "aca_environment_id" {
  description = "Resource ID of the Container Apps Environment."
  value       = azurerm_container_app_environment.main.id
}

output "aca_environment_default_domain" {
  description = "Default domain of the Container Apps Environment."
  value       = azurerm_container_app_environment.main.default_domain
}

output "web_container_app_id" {
  description = "Resource ID of the Web container app."
  value       = azurerm_container_app.web.id
}

output "web_fqdn" {
  description = "FQDN of the Web container app."
  value       = azurerm_container_app.web.ingress[0].fqdn
}

output "web_latest_revision_fqdn" {
  description = "Latest revision FQDN of the Web container app."
  value       = azurerm_container_app.web.latest_revision_fqdn
}

output "api_container_app_id" {
  description = "Resource ID of the API container app."
  value       = azurerm_container_app.api.id
}

output "api_fqdn" {
  description = "FQDN of the API container app."
  value       = azurerm_container_app.api.ingress[0].fqdn
}

output "api_latest_revision_fqdn" {
  description = "Latest revision FQDN of the API container app."
  value       = azurerm_container_app.api.latest_revision_fqdn
}

output "static_web_app_url" {
  description = "Default hostname of the Azure Static Web App."
  value       = azurerm_static_web_app.blazor_admin.default_host_name
}

output "static_web_app_id" {
  description = "Resource ID of the Static Web App."
  value       = azurerm_static_web_app.blazor_admin.id
}

output "static_web_app_api_key" {
  description = "API key for the Static Web App deployment."
  value       = azurerm_static_web_app.blazor_admin.api_key
  sensitive   = true
}
