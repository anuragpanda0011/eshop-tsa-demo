output "key_vault_id" {
  description = "Key Vault resource ID."
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "Key Vault URI."
  value       = azurerm_key_vault.main.vault_uri
}

output "managed_identity_id" {
  description = "User-assigned managed identity resource ID."
  value       = azurerm_user_assigned_identity.main.id
}

output "managed_identity_client_id" {
  description = "User-assigned managed identity client ID."
  value       = azurerm_user_assigned_identity.main.client_id
}

output "managed_identity_principal_id" {
  description = "User-assigned managed identity principal ID."
  value       = azurerm_user_assigned_identity.main.principal_id
}

output "front_door_endpoint_hostname" {
  description = "Default Front Door endpoint hostname."
  value       = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "front_door_profile_id" {
  description = "Front Door profile resource ID."
  value       = azurerm_cdn_frontdoor_profile.main.id
}

output "waf_policy_id" {
  description = "WAF policy resource ID."
  value       = azurerm_cdn_frontdoor_firewall_policy.main.id
}
