output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  value = { for k, v in azurerm_subnet.subnets : k => v.id }
}

output "subnet_address_prefixes" {
  value = { for k, v in azurerm_subnet.subnets : k => v.address_prefixes[0] }
}

output "nat_gateway_public_ip" {
  value = azurerm_public_ip.nat.ip_address
}

output "nat_gateway_id" {
  value = azurerm_nat_gateway.main.id
}

output "private_dns_zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.zones : k => v.id }
}

output "private_dns_zone_names" {
  value = { for k, v in azurerm_private_dns_zone.zones : k => v.name }
}
