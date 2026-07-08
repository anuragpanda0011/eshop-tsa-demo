output "web_app_id" {
  description = "Resource ID of the Web App Service."
  value       = azurerm_linux_web_app.web.id
}

output "web_app_hostname" {
  description = "Default hostname of the Web App Service."
  value       = azurerm_linux_web_app.web.default_hostname
}

output "web_app_principal_id" {
  description = "System-Assigned Managed Identity principal ID of the Web App."
  value       = azurerm_linux_web_app.web.identity[0].principal_id
}

output "api_app_id" {
  description = "Resource ID of the API App Service."
  value       = azurerm_linux_web_app.api.id
}

output "api_app_hostname" {
  description = "Default hostname of the API App Service."
  value       = azurerm_linux_web_app.api.default_hostname
}

output "api_app_principal_id" {
  description = "System-Assigned Managed Identity principal ID of the API App."
  value       = azurerm_linux_web_app.api.identity[0].principal_id
}

output "acr_id" {
  description = "Resource ID of the Azure Container Registry."
  value       = azurerm_container_registry.main.id
}

output "acr_login_server" {
  description = "Azure Container Registry login server URL."
  value       = azurerm_container_registry.main.login_server
}

output "web_app_plan_id" {
  description = "Resource ID of the Web App Service Plan."
  value       = azurerm_service_plan.web.id
}

output "api_app_plan_id" {
  description = "Resource ID of the API App Service Plan."
  value       = azurerm_service_plan.api.id
}
