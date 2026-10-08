output "catalog_server_id" {
  description = "Resource ID of the catalog SQL server."
  value       = azurerm_mssql_server.catalog.id
}

output "catalog_server_fqdn" {
  description = "Fully qualified domain name of the catalog SQL server."
  value       = azurerm_mssql_server.catalog.fully_qualified_domain_name
}

output "catalog_database_id" {
  description = "Resource ID of the catalog database."
  value       = azurerm_mssql_database.catalog.id
}

output "identity_server_id" {
  description = "Resource ID of the identity SQL server."
  value       = azurerm_mssql_server.identity.id
}

output "identity_server_fqdn" {
  description = "Fully qualified domain name of the identity SQL server."
  value       = azurerm_mssql_server.identity.fully_qualified_domain_name
}

output "identity_database_id" {
  description = "Resource ID of the identity database."
  value       = azurerm_mssql_database.identity.id
}

output "redis_id" {
  description = "Resource ID of the Redis cache."
  value       = azurerm_redis_cache.main.id
}

output "redis_hostname" {
  description = "Hostname of the Redis cache."
  value       = azurerm_redis_cache.main.hostname
}

output "redis_ssl_port" {
  description = "SSL port of the Redis cache."
  value       = azurerm_redis_cache.main.ssl_port
}

# SECURITY NOTE: The Redis primary_access_key is intentionally NOT exposed as
# an output to prevent it from being readable from state by consumers of this
# module. The CI/CD pipeline must retrieve the key directly from the Redis
# resource using az redis list-keys (Key Vault Secrets Officer role) and inject
# it into the Key Vault secret post-deploy.
output "redis_connection_string" {
  description = "Redis connection string stub (hostname:port only, no access key). CI/CD must inject the full string with access key into Key Vault post-deploy."
  value       = "${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port},ssl=True,abortConnect=False"
  sensitive   = true
}

output "catalog_connection_string" {
  description = "Catalog DB connection string (Managed Identity auth, no password)."
  value       = azurerm_key_vault_secret.catalog_connection_string.value
  sensitive   = true
}

output "identity_connection_string" {
  description = "Identity DB connection string (Managed Identity auth, no password)."
  value       = azurerm_key_vault_secret.identity_connection_string.value
  sensitive   = true
}

output "catalog_connection_string_secret_id" {
  description = "Key Vault secret ID for the catalog connection string."
  value       = azurerm_key_vault_secret.catalog_connection_string.id
}

output "identity_connection_string_secret_id" {
  description = "Key Vault secret ID for the identity connection string."
  value       = azurerm_key_vault_secret.identity_connection_string.id
}

output "redis_connection_string_secret_id" {
  description = "Key Vault secret ID for the Redis connection string."
  value       = azurerm_key_vault_secret.redis_connection_string.id
}
