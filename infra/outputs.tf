output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Name of the primary resource group."
}

output "vnet_id" {
  value       = module.network.vnet_id
  description = "Resource ID of the primary Virtual Network."
}

output "acr_login_server" {
  value       = module.compute.acr_login_server
  description = "Azure Container Registry login server FQDN."
}

output "aca_web_fqdn" {
  value       = module.compute.aca_web_fqdn
  description = "Internal FQDN of the Web Container App."
}

output "aca_api_fqdn" {
  value       = module.compute.aca_api_fqdn
  description = "Internal FQDN of the API Container App."
}

output "key_vault_uri" {
  value       = module.security.key_vault_uri
  description = "URI of the Azure Key Vault."
}

output "app_insights_connection_string" {
  value       = module.monitoring.app_insights_connection_string
  sensitive   = true
  description = "Application Insights connection string. Use this for AAD-authenticated ingestion. instrumentation_key output has been removed."
}

output "front_door_endpoint_hostname" {
  value       = module.network.front_door_endpoint_hostname
  description = "Azure Front Door endpoint hostname."
}

output "static_web_app_url" {
  value       = module.compute.static_web_app_url
  description = "URL of the Azure Static Web App (BlazorAdmin) — AAD authentication enforced by Terraform."
}

output "static_web_app_id" {
  value       = module.compute.static_web_app_id
  description = "Resource ID of the Azure Static Web App."
}

output "sql_server_fqdn" {
  value       = module.database.sql_server_fqdn
  description = "FQDN of the Azure SQL Server."
}

output "redis_hostname" {
  value       = module.database.redis_hostname
  description = "Hostname of the Azure Cache for Redis."
}

output "github_actions_client_id" {
  value       = module.ci_cd.github_actions_client_id
  description = "Client ID of the Azure AD application used by GitHub Actions OIDC."
}

output "managed_identity_web_client_id" {
  value       = module.security.managed_identity_web_client_id
  description = "Client ID of the web app user-assigned managed identity."
}

output "managed_identity_api_client_id" {
  value       = module.security.managed_identity_api_client_id
  description = "Client ID of the API user-assigned managed identity."
}

output "apim_gateway_url" {
  value       = module.compute.apim_gateway_url
  description = "Azure API Management gateway URL."
}

output "nat_public_ips" {
  value       = [module.network.nat_public_ip_z1, module.network.nat_public_ip_z2, module.network.nat_public_ip_z3]
  description = "Zone-redundant NAT Gateway public IP addresses (one per availability zone)."
}

output "log_analytics_workspace_guid" {
  value       = module.monitoring_bootstrap.log_analytics_workspace_guid
  description = "Log Analytics Workspace GUID — use this value for log_analytics_workspace_guid variable on subsequent applies."
}
