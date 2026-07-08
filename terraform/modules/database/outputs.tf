output "catalog_sql_server_id" {
  description = "Resource ID of the Catalog SQL Server."
  value       = azurerm_mssql_server.catalog.id
}

output "catalog_sql_server_fqdn" {
  description = "FQDN of the Catalog SQL Server."
  value       = azurerm_mssql_server.catalog.fully_qualified_domain_name
}

output "catalog_database_id" {
  description = "Resource ID of the Catalog SQL Database."
  value       = azurerm_mssql_database.catalog.id
}

output "identity_sql_server_id" {
  description = "Resource ID of the Identity SQL Server."
  value       = azurerm_mssql_server.identity.id
}

output "identity_sql_server_fqdn" {
  description = "FQDN of the Identity SQL Server."
  value       = azurerm_mssql_server.identity.fully_qualified_domain_name
}

output "identity_database_id" {
  description = "Resource ID of the Identity SQL Database."
  value       = azurerm_mssql_database.identity.id
}

output "redis_id" {
  description = "Resource ID of the Azure Cache for Redis."
  value       = azurerm_redis_cache.main.id
}

output "redis_hostname" {
  description = "Hostname of the Azure Cache for Redis."
  value       = azurerm_redis_cache.main.hostname
  sensitive   = true
}

output "redis_primary_access_key" {
  description = "Primary access key for Azure Cache for Redis."
  value       = azurerm_redis_cache.main.primary_access_key
  sensitive   = true
}

output "redis_connection_string" {
  description = "Redis connection string."
  value       = "${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port},password=${azurerm_redis_cache.main.primary_access_key},ssl=True,abortConnect=False"
  sensitive   = true
}

output "storage_account_id" {
  description = "Resource ID of the product images storage account."
  value       = azurerm_storage_account.images.id
}

output "storage_account_name" {
  description = "Name of the product images storage account."
  value       = azurerm_storage_account.images.name
}

output "storage_primary_blob_endpoint" {
  description = "Primary blob endpoint of the product images storage account."
  value       = azurerm_storage_account.images.primary_blob_endpoint
}
