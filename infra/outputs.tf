output "resource_group_name" {
  description = "Name of the primary resource group."
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "Resource ID of the primary virtual network."
  value       = module.network.vnet_id
}

output "acr_login_server" {
  description = "Login server URL for the Azure Container Registry."
  value       = module.compute.acr_login_server
}

output "web_container_app_fqdn" {
  description = "FQDN of the Web container app."
  value       = module.compute.web_fqdn
}

output "api_container_app_fqdn" {
  description = "FQDN of the API container app."
  value       = module.compute.api_fqdn
}

output "front_door_endpoint" {
  description = "Azure Front Door endpoint hostname."
  value       = module.network.front_door_endpoint_host
}

output "front_door_profile_resource_guid" {
  description = "Resource GUID of the Front Door profile. Use this value as var.front_door_profile_resource_guid on subsequent applies to populate the APIM header validation policy."
  value       = module.network.front_door_profile_resource_guid
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault."
  value       = module.security.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault."
  value       = module.security.key_vault_uri
}

output "app_insights_connection_string" {
  description = "Application Insights connection string (sensitive)."
  value       = module.monitoring.app_insights_connection_string
  sensitive   = true
}

output "static_web_app_url" {
  description = "Default hostname of the Azure Static Web App."
  value       = module.compute.static_web_app_url
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = module.monitoring.log_analytics_workspace_id
}

output "web_managed_identity_client_id" {
  description = "Client ID of the Web user-assigned managed identity."
  value       = module.security.web_managed_identity_client_id
}

output "api_managed_identity_client_id" {
  description = "Client ID of the API user-assigned managed identity."
  value       = module.security.api_managed_identity_client_id
}

output "cicd_service_principal_client_id" {
  description = "Client ID of the CI/CD OIDC service principal."
  value       = module.security.cicd_service_principal_client_id
}

output "catalog_db_fqdn" {
  description = "FQDN of the catalog SQL server."
  value       = module.database.catalog_server_fqdn
}

output "identity_db_fqdn" {
  description = "FQDN of the identity SQL server."
  value       = module.database.identity_server_fqdn
}

output "redis_hostname" {
  description = "Hostname of the Redis cache (for post-deploy key injection)."
  value       = module.database.redis_hostname
}

output "redis_ssl_port" {
  description = "SSL port of the Redis cache (for post-deploy key injection)."
  value       = module.database.redis_ssl_port
}
