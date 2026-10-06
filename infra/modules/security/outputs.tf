output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "kv_private_endpoint_id" {
  value = azurerm_private_endpoint.kv.id
}

output "acr_id" {
  value = azurerm_container_registry.main.id
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "acr_private_endpoint_id" {
  value = azurerm_private_endpoint.acr.id
}

output "kv_secret_catalog_conn_id" {
  value = azurerm_key_vault_secret.sql_catalog_connection_string.id
}

output "kv_secret_identity_conn_id" {
  value = azurerm_key_vault_secret.sql_identity_connection_string.id
}

output "acr_immutable_policy_assignment_id" {
  value       = azurerm_resource_group_policy_assignment.acr_immutable_tags.id
  description = "Resource ID of the ACR immutable tag policy assignment"
}
