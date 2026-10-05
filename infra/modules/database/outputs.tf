output "sql_server_id" {
  value = azurerm_mssql_server.main.id
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_server_name" {
  value = azurerm_mssql_server.main.name
}

output "catalogdb_id" {
  value = azurerm_mssql_database.catalogdb.id
}

output "catalogdb_name" {
  value = azurerm_mssql_database.catalogdb.name
}

output "identitydb_id" {
  value = azurerm_mssql_database.identitydb.id
}

output "identitydb_name" {
  value = azurerm_mssql_database.identitydb.name
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

output "redis_name" {
  value = azurerm_redis_cache.main.name
}

# FIX: Mark redis primary_access_key output as sensitive to prevent accidental
# exposure in logs and plan output. This does not prevent it from being written
# to state — CMK on the state backend remains mandatory.
output "redis_primary_access_key" {
  value     = azurerm_redis_cache.main.primary_access_key
  sensitive = true
}

output "private_endpoint_sql_id" {
  value = azurerm_private_endpoint.sql.id
}

output "private_endpoint_redis_id" {
  value = azurerm_private_endpoint.redis.id
}
