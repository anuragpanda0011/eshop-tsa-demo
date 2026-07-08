# ---------------------------------------------------------------------------
# Root outputs — expose key resource identifiers for operators / pipelines
# ---------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the primary resource group."
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "Resource ID of the primary resource group."
  value       = azurerm_resource_group.main.id
}

# --- Networking ---
output "vnet_id" {
  description = "Virtual Network resource ID."
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "Virtual Network name."
  value       = module.network.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet name → subnet resource ID."
  value       = module.network.subnet_ids
}

output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway."
  value       = module.network.appgw_public_ip
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway."
  value       = module.network.nat_gateway_public_ip
}

# --- Compute ---
output "web_app_hostname" {
  description = "Default hostname of the Web App Service."
  value       = module.compute.web_app_hostname
}

output "api_app_hostname" {
  description = "Default hostname of the API App Service."
  value       = module.compute.api_app_hostname
}

output "acr_login_server" {
  description = "Azure Container Registry login server URL."
  value       = module.compute.acr_login_server
}

output "web_app_principal_id" {
  description = "Managed Identity principal ID of the Web App Service."
  value       = module.compute.web_app_principal_id
}

output "api_app_principal_id" {
  description = "Managed Identity principal ID of the API App Service."
  value       = module.compute.api_app_principal_id
}

# --- Database ---
output "catalog_sql_server_fqdn" {
  description = "FQDN of the Catalog SQL Server."
  value       = module.database.catalog_sql_server_fqdn
}

output "identity_sql_server_fqdn" {
  description = "FQDN of the Identity SQL Server."
  value       = module.database.identity_sql_server_fqdn
}

output "redis_hostname" {
  description = "Hostname of the Azure Cache for Redis instance."
  value       = module.database.redis_hostname
  sensitive   = true
}

output "storage_account_name" {
  description = "Name of the Blob Storage account for product images."
  value       = module.database.storage_account_name
}

# --- Security ---
output "key_vault_uri" {
  description = "URI of the Azure Key Vault."
  value       = module.security.key_vault_uri
}

output "key_vault_id" {
  description = "Resource ID of the Azure Key Vault."
  value       = module.security.key_vault_id
}

output "user_assigned_identity_client_id" {
  description = "Client ID of the User-Assigned Managed Identity for CI/CD."
  value       = module.security.user_assigned_identity_client_id
}

# --- Monitoring ---
output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key."
  value       = module.monitoring.app_insights_instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string."
  value       = module.monitoring.app_insights_connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID."
  value       = module.monitoring.log_analytics_workspace_id
}

# --- Front Door ---
output "front_door_endpoint_hostname" {
  description = "Azure Front Door endpoint hostname."
  value       = module.network.front_door_endpoint_hostname
}
