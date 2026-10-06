output "sql_catalog_server_id" {
  value = azurerm_mssql_server.catalog.id
}

output "sql_catalog_server_fqdn" {
  value = azurerm_mssql_server.catalog.fully_qualified_domain_name
}

output "sql_catalog_db_id" {
  value = azurerm_mssql_database.catalog.id
}

output "sql_identity_server_id" {
  value = azurerm_mssql_server.identity.id
}

output "sql_identity_server_fqdn" {
  value = azurerm_mssql_server.identity.fully_qualified_domain_name
}

output "sql_identity_db_id" {
  value = azurerm_mssql_database.identity.id
}

output "redis_id" {
  value = azurerm_redis_cache.main.id
}

output "redis_hostname" {
  value = azurerm_redis_cache.main.hostname
}

output "redis_ssl_port" {
  value = azurerm_redis_cache.main.ssl_port
}

output "redis_primary_access_key" {
  value     = azurerm_redis_cache.main.primary_access_key
  sensitive = true
}

output "redis_primary_connection_string" {
  value     = azurerm_redis_cache.main.primary_connection_string
  sensitive = true
}

output "sql_catalog_private_endpoint_id" {
  value = azurerm_private_endpoint.sql_catalog.id
}

output "sql_identity_private_endpoint_id" {
  value = azurerm_private_endpoint.sql_identity.id
}

output "redis_private_endpoint_id" {
  value = azurerm_private_endpoint.redis.id
}
