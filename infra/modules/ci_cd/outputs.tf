output "front_door_profile_id" {
  value = azurerm_cdn_frontdoor_profile.main.id
}

output "front_door_profile_name" {
  value = azurerm_cdn_frontdoor_profile.main.name
}

output "front_door_endpoint_hostname" {
  value = azurerm_cdn_frontdoor_endpoint.web.host_name
}

output "front_door_api_endpoint_hostname" {
  value = azurerm_cdn_frontdoor_endpoint.api.host_name
}

output "waf_policy_id" {
  value = azurerm_cdn_frontdoor_firewall_policy.main.id
}

output "custom_domain_validation_token" {
  value = azurerm_cdn_frontdoor_custom_domain.web.validation_token
}

output "dns_cname_record_fqdn" {
  value = azurerm_dns_cname_record.web.fqdn
}
