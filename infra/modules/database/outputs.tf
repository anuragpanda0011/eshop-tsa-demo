output "catalog_sql_fqdn" {
  description = "FQDN of the Catalog SQL Server."
  value       = azurerm_mssql_server.catalog.fully_qualified_domain_name
}

output "identity_sql_fqdn" {
  description = "FQDN of the Identity SQL Server."
  value       = azurerm_mssql_server.identity.fully_qualified_domain_name
}

output "catalog_sql_server_id" {
  description = "Resource ID of the Catalog SQL Server."
  value       = azurerm_mssql_server.catalog.id
}

output "identity_sql_server_id" {
  description = "Resource ID of the Identity SQL Server."
  value       = azurerm_mssql_server.identity.id
}

output "catalog_db_id" {
  description = "Resource ID of the Catalog SQL Database."
  value       = azurerm_mssql_database.catalog.id
}

output "identity_db_id" {
  description = "Resource ID of the Identity SQL Database."
  value       = azurerm_mssql_database.identity.id
}

output "redis_hostname" {
  description = "Redis cache hostname."
  value       = azurerm_redis_cache.main.hostname
}

output "redis_ssl_port" {
  description = "Redis cache SSL port."
  value       = azurerm_redis_cache.main.ssl_port
}

output "redis_id" {
  description = "Redis cache resource ID."
  value       = azurerm_redis_cache.main.id
}

output "storage_account_id" {
  description = "Storage account resource ID."
  value       = azurerm_storage_account.images.id
}

output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.images.name
}

output "images_container_name" {
  description = "Blob container name for product images."
  value       = azurerm_storage_container.images.name
}

output "catalog_conn_kv_secret_name" {
  description = "Key Vault secret name for Catalog DB connection string."
  value       = azurerm_key_vault_secret.catalog_connection_string.name
}

output "identity_conn_kv_secret_name" {
  description = "Key Vault secret name for Identity DB connection string."
  value       = azurerm_key_vault_secret.identity_connection_string.name
}

output "redis_conn_kv_secret_name" {
  description = "Key Vault secret name for Redis connection string."
  value       = azurerm_key_vault_secret.redis_connection_string.name
}
