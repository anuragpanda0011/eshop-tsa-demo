###############################################################################
# Network
###############################################################################
output "vnet_id" {
  description = "Virtual Network resource ID"
  value       = module.network.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet name → resource ID"
  value       = module.network.subnet_ids
}

output "nat_gateway_public_ip" {
  description = "Static public IP attached to NAT Gateway"
  value       = module.network.nat_gateway_public_ip
}

###############################################################################
# Compute
###############################################################################
output "web_app_name" {
  description = "Web App Service name"
  value       = module.compute.web_app_name
}

output "web_app_hostname" {
  description = "Web App default hostname"
  value       = module.compute.web_app_default_hostname
}

output "api_app_name" {
  description = "API App Service name"
  value       = module.compute.api_app_name
}

output "api_app_hostname" {
  description = "API App default hostname"
  value       = module.compute.api_app_default_hostname
}

output "web_app_managed_identity_principal_id" {
  description = "Principal ID of Web App system-assigned identity"
  value       = module.compute.web_app_principal_id
}

output "api_app_managed_identity_principal_id" {
  description = "Principal ID of API App system-assigned identity"
  value       = module.compute.api_app_principal_id
}

###############################################################################
# Database
###############################################################################
output "sql_catalog_server_fqdn" {
  description = "FQDN of the Catalog SQL Server"
  value       = module.database.sql_catalog_server_fqdn
}

output "sql_identity_server_fqdn" {
  description = "FQDN of the Identity SQL Server"
  value       = module.database.sql_identity_server_fqdn
}

###############################################################################
# Security
###############################################################################
output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.security.key_vault_uri
}

output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = module.security.key_vault_id
}

output "acr_login_server" {
  description = "ACR login server URL"
  value       = module.security.acr_login_server
}

###############################################################################
# Monitoring
###############################################################################
output "app_insights_connection_string" {
  description = "Application Insights connection string"
  value       = module.monitoring.app_insights_connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID"
  value       = module.monitoring.log_analytics_workspace_id
}

###############################################################################
# Front Door
###############################################################################
output "front_door_endpoint_hostname" {
  description = "Azure Front Door endpoint hostname"
  value       = module.ci_cd.front_door_endpoint_hostname
}
