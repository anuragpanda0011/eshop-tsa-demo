output "acr_id" {
  description = "ACR resource ID."
  value       = azurerm_container_registry.main.id
}

output "acr_login_server" {
  description = "ACR login server FQDN."
  value       = azurerm_container_registry.main.login_server
}

output "acr_name" {
  description = "ACR name."
  value       = azurerm_container_registry.main.name
}

output "aca_environment_id" {
  description = "Container Apps Environment resource ID."
  value       = azurerm_container_app_environment.main.id
}

output "aca_web_id" {
  description = "Web Container App resource ID."
  value       = azurerm_container_app.web.id
}

output "aca_web_fqdn" {
  description = "Web Container App FQDN."
  value       = azurerm_container_app.web.ingress[0].fqdn
}

output "aca_api_id" {
  description = "API Container App resource ID."
  value       = azurerm_container_app.api.id
}

output "aca_api_fqdn" {
  description = "API Container App FQDN."
  value       = azurerm_container_app.api.ingress[0].fqdn
}

output "swa_default_hostname" {
  description = "Static Web Apps default hostname."
  value       = azurerm_static_web_app.blazoradmin.default_host_name
}

output "swa_id" {
  description = "Static Web Apps resource ID."
  value       = azurerm_static_web_app.blazoradmin.id
}
