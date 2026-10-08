output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.main.name
}

output "aca_infra_subnet_id" {
  description = "Resource ID of the ACA infrastructure subnet."
  value       = azurerm_subnet.aca_infra.id
}

output "aca_apps_subnet_id" {
  description = "Resource ID of the ACA apps subnet."
  value       = azurerm_subnet.aca_apps.id
}

output "private_endpoint_subnet_id" {
  description = "Resource ID of the private endpoints subnet."
  value       = azurerm_subnet.private_endpoints.id
}

output "redis_subnet_id" {
  description = "Resource ID of the Redis subnet."
  value       = azurerm_subnet.redis.id
}

output "devops_agents_subnet_id" {
  description = "Resource ID of the DevOps agents subnet."
  value       = azurerm_subnet.devops_agents.id
}

output "apim_subnet_id" {
  description = "Resource ID of the APIM subnet."
  value       = azurerm_subnet.apim.id
}

output "nat_gateway_id" {
  description = "Resource ID of the NAT gateway."
  value       = azurerm_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT gateway."
  value       = azurerm_public_ip.nat.ip_address
}

output "private_dns_zone_sql_id" {
  description = "Resource ID of the SQL private DNS zone."
  value       = azurerm_private_dns_zone.sql.id
}

output "private_dns_zone_sql_name" {
  description = "Name of the SQL private DNS zone."
  value       = azurerm_private_dns_zone.sql.name
}

output "private_dns_zone_kv_id" {
  description = "Resource ID of the Key Vault private DNS zone."
  value       = azurerm_private_dns_zone.keyvault.id
}

output "private_dns_zone_kv_name" {
  description = "Name of the Key Vault private DNS zone."
  value       = azurerm_private_dns_zone.keyvault.name
}

output "private_dns_zone_acr_id" {
  description = "Resource ID of the ACR private DNS zone."
  value       = azurerm_private_dns_zone.acr.id
}

output "private_dns_zone_acr_name" {
  description = "Name of the ACR private DNS zone."
  value       = azurerm_private_dns_zone.acr.name
}

output "private_dns_zone_redis_id" {
  description = "Resource ID of the Redis private DNS zone."
  value       = azurerm_private_dns_zone.redis.id
}

output "private_dns_zone_redis_name" {
  description = "Name of the Redis private DNS zone."
  value       = azurerm_private_dns_zone.redis.name
}

output "private_dns_zone_blob_id" {
  description = "Resource ID of the Blob private DNS zone."
  value       = azurerm_private_dns_zone.blob.id
}

output "private_dns_zone_blob_name" {
  description = "Name of the Blob private DNS zone."
  value       = azurerm_private_dns_zone.blob.name
}

output "front_door_profile_id" {
  description = "Resource ID of the Front Door profile."
  value       = azurerm_cdn_frontdoor_profile.main.id
}

output "front_door_profile_resource_guid" {
  description = "Resource GUID of the Front Door profile (used for X-Azure-FDID header validation in APIM)."
  value       = azurerm_cdn_frontdoor_profile.main.resource_guid
}

output "front_door_endpoint_host" {
  description = "Hostname of the Front Door endpoint."
  value       = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "front_door_endpoint_id" {
  description = "Resource ID of the Front Door endpoint."
  value       = azurerm_cdn_frontdoor_endpoint.main.id
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance."
  value       = azurerm_api_management.main.gateway_url
}

output "apim_id" {
  description = "Resource ID of the API Management instance."
  value       = azurerm_api_management.main.id
}

output "apim_principal_id" {
  description = "Principal ID of the APIM system-assigned managed identity."
  value       = azurerm_api_management.main.identity[0].principal_id
}

output "bastion_id" {
  description = "Resource ID of the Azure Bastion host."
  value       = azurerm_bastion_host.main.id
}
