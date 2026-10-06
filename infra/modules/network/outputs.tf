output "vnet_id" {
  description = "Resource ID of the VNet."
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the VNet."
  value       = azurerm_virtual_network.main.name
}

output "aca_infra_subnet_id" {
  description = "Subnet ID for Container Apps infrastructure."
  value       = azurerm_subnet.aca_infra.id
}

output "aca_apps_subnet_id" {
  description = "Subnet ID for Container Apps workloads."
  value       = azurerm_subnet.aca_apps.id
}

output "private_endpoint_subnet_id" {
  description = "Subnet ID for Private Endpoints."
  value       = azurerm_subnet.private_endpoints.id
}

output "redis_subnet_id" {
  description = "Subnet ID for Redis."
  value       = azurerm_subnet.redis.id
}

output "bastion_subnet_id" {
  description = "Subnet ID for Azure Bastion."
  value       = azurerm_subnet.bastion.id
}

output "nsg_aca_id" {
  description = "NSG ID for ACA subnets."
  value       = azurerm_network_security_group.nsg_aca.id
}

output "nsg_pe_id" {
  description = "NSG ID for Private Endpoint subnet."
  value       = azurerm_network_security_group.nsg_pe.id
}

output "nsg_redis_id" {
  description = "NSG ID for Redis subnet."
  value       = azurerm_network_security_group.nsg_redis.id
}

output "nat_gateway_id" {
  description = "NAT Gateway resource ID."
  value       = azurerm_nat_gateway.main.id
}

output "ddos_protection_plan_id" {
  description = "DDoS Protection Plan resource ID (empty string if disabled)."
  value       = var.ddos_protection_plan_enabled ? azurerm_network_ddos_protection_plan.main[0].id : ""
}
