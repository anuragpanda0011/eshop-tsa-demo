output "resource_group_name" {
  description = "Name of the primary resource group."
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "Resource ID of the primary VNet."
  value       = module.network.vnet_id
}

output "acr_login_server" {
  description = "ACR login server FQDN."
  value       = module.compute.acr_login_server
}

output "aca_web_fqdn" {
  description = "Internal FQDN of the Web Container App."
  value       = module.compute.aca_web_fqdn
}

output "aca_api_fqdn" {
  description = "Internal FQDN of the API Container App."
  value       = module.compute.aca_api_fqdn
}

output "key_vault_uri" {
  description = "Key Vault URI."
  value       = module.security.key_vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID."
  value       = module.monitoring.log_analytics_workspace_id
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key (sensitive)."
  value       = module.monitoring.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string (sensitive)."
  value       = module.monitoring.connection_string
  sensitive   = true
}

output "front_door_endpoint_hostname" {
  description = "Front Door default endpoint hostname."
  value       = module.security.front_door_endpoint_hostname
}

output "managed_identity_client_id" {
  description = "Client ID of the user-assigned managed identity."
  value       = module.security.managed_identity_client_id
}

output "redis_hostname" {
  description = "Redis cache hostname."
  value       = module.database.redis_hostname
}

output "catalog_sql_fqdn" {
  description = "Catalog SQL Server FQDN."
  value       = module.database.catalog_sql_fqdn
}

output "identity_sql_fqdn" {
  description = "Identity SQL Server FQDN."
  value       = module.database.identity_sql_fqdn
}

output "static_web_app_default_hostname" {
  description = "Static Web App default hostname."
  value       = module.compute.swa_default_hostname
}

output "cicd_service_principal_app_id" {
  description = "App ID of the GitHub Actions service principal."
  value       = module.ci_cd.service_principal_app_id
}
