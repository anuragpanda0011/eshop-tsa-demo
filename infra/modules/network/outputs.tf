output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "subnet_aca_infra_id" {
  value = azurerm_subnet.aca_infra.id
}

output "subnet_aca_apps_id" {
  value = azurerm_subnet.aca_apps.id
}

output "subnet_pe_id" {
  value = azurerm_subnet.pe.id
}

output "subnet_appgw_id" {
  value = azurerm_subnet.appgw.id
}

output "subnet_redis_id" {
  value = azurerm_subnet.redis.id
}

output "subnet_agents_id" {
  value = azurerm_subnet.agents.id
}

output "subnet_bastion_id" {
  value = azurerm_subnet.bastion.id
}

output "subnet_apim_id" {
  value = azurerm_subnet.apim.id
}

output "nat_gateway_id" {
  value = azurerm_nat_gateway.main.id
}

output "private_dns_zone_sql_id" {
  value = azurerm_private_dns_zone.sql.id
}

output "private_dns_zone_keyvault_id" {
  value = azurerm_private_dns_zone.keyvault.id
}

output "private_dns_zone_acr_id" {
  value = azurerm_private_dns_zone.acr.id
}

output "private_dns_zone_redis_id" {
  value = azurerm_private_dns_zone.redis.id
}

output "private_dns_zone_blob_id" {
  value = azurerm_private_dns_zone.blob.id
}

output "private_dns_zone_websites_id" {
  value = azurerm_private_dns_zone.websites.id
}

output "front_door_id" {
  value = azurerm_cdn_frontdoor_profile.main.id
}

output "front_door_endpoint_hostname" {
  value = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "front_door_profile_name" {
  value = azurerm_cdn_frontdoor_profile.main.name
}

output "nsg_aca_infra_id" {
  value = azurerm_network_security_group.aca_infra.id
}

output "nsg_aca_apps_id" {
  value = azurerm_network_security_group.aca_apps.id
}

output "nsg_pe_id" {
  value = azurerm_network_security_group.pe.id
}

output "ddos_plan_id" {
  value = azurerm_network_ddos_protection_plan.main.id
}

output "flowlogs_storage_account_id" {
  value = azurerm_storage_account.flowlogs.id
}

output "nat_public_ip_z1" {
  value = azurerm_public_ip.nat_z1.ip_address
}

output "nat_public_ip_z2" {
  value = azurerm_public_ip.nat_z2.ip_address
}

output "nat_public_ip_z3" {
  value = azurerm_public_ip.nat_z3.ip_address
}
