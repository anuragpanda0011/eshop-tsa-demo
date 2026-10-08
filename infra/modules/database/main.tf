# ===========================================================================
# Database Module
# Provisions: Azure SQL Servers (Entra-only auth), Databases, Private Endpoints,
#             Azure Cache for Redis, Private Endpoint for Redis,
#             Key Vault secrets for connection strings
# ===========================================================================

locals {
  prefix = "${var.project}-${var.environment}"
}

data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Random suffix to ensure globally unique SQL server names
# ---------------------------------------------------------------------------
resource "random_string" "sql_suffix" {
  length  = 6
  upper   = false
  special = false
}

# ---------------------------------------------------------------------------
# SQL Server — Catalog
# ---------------------------------------------------------------------------
resource "azurerm_mssql_server" "catalog" {
  name                          = "sql-${var.project}-catalog-${var.environment}-${random_string.sql_suffix.result}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  azuread_administrator {
    login_username = "sql-admin-entra"
    object_id      = data.azurerm_client_config.current.object_id
    # Entra-only authentication: SQL password auth is disabled.
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "catalog" {
  server_id          = azurerm_mssql_server.catalog.id
  log_monitoring_enabled = true
  retention_in_days  = 90
}

resource "azurerm_mssql_database" "catalog" {
  name                        = "catalogdb"
  server_id                   = azurerm_mssql_server.catalog.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  sku_name                    = var.sql_sku_name
  max_size_gb                 = var.sql_max_size_gb
  zone_redundant              = true
  geo_backup_enabled          = true
  auto_pause_delay_in_minutes = -1 # -1 = disabled (always on for production)
  tags                        = var.tags

  short_term_retention_policy {
    retention_days           = 7
    backup_interval_in_hours = 12
  }

  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P12M"
    yearly_retention  = "P5Y"
    week_of_year      = 1
  }

  threat_detection_policy {
    state                = "Enabled"
    email_account_admins = "Enabled"
    retention_days       = 90
  }
}

# ---------------------------------------------------------------------------
# SQL Server — Identity
# ---------------------------------------------------------------------------
resource "azurerm_mssql_server" "identity" {
  name                          = "sql-${var.project}-identity-${var.environment}-${random_string.sql_suffix.result}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  azuread_administrator {
    login_username = "sql-admin-entra"
    object_id      = data.azurerm_client_config.current.object_id
    # Entra-only authentication: SQL password auth is disabled.
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "identity" {
  server_id              = azurerm_mssql_server.identity.id
  log_monitoring_enabled = true
  retention_in_days      = 90
}

resource "azurerm_mssql_database" "identity" {
  name                        = "identitydb"
  server_id                   = azurerm_mssql_server.identity.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  sku_name                    = var.sql_sku_name
  max_size_gb                 = var.sql_max_size_gb
  zone_redundant              = true
  geo_backup_enabled          = true
  auto_pause_delay_in_minutes = -1
  tags                        = var.tags

  short_term_retention_policy {
    retention_days           = 7
    backup_interval_in_hours = 12
  }

  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P12M"
    yearly_retention  = "P5Y"
    week_of_year      = 1
  }

  threat_detection_policy {
    state                = "Enabled"
    email_account_admins = "Enabled"
    retention_days       = 90
  }
}

# ---------------------------------------------------------------------------
# Private Endpoints — SQL Servers
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "catalog_sql" {
  name                = "pe-sql-catalog-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-catalog-${local.prefix}"
    private_connection_resource_id = azurerm_mssql_server.catalog.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-catalog-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_sql_id]
  }
}

resource "azurerm_private_endpoint" "identity_sql" {
  name                = "pe-sql-identity-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-identity-${local.prefix}"
    private_connection_resource_id = azurerm_mssql_server.identity.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-identity-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_sql_id]
  }
}

# NOTE: The AllowAzureServices firewall rules (0.0.0.0/0.0.0.0) that were
# previously present have been removed. With public_network_access_enabled=false
# and Entra-only auth enforced, all access must flow through private endpoints.
# EF migrations must run from within the VNet (e.g., a DevOps agent subnet).

# ---------------------------------------------------------------------------
# Azure Cache for Redis — Standard C1
# ---------------------------------------------------------------------------
resource "azurerm_redis_cache" "main" {
  name                          = "redis-${local.prefix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = var.redis_capacity
  family                        = var.redis_family
  sku_name                      = var.redis_sku
  non_ssl_port_enabled          = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  redis_configuration {
    maxmemory_reserved    = 50
    maxmemory_delta       = 50
    maxmemory_policy      = "allkeys-lru"
    enable_authentication = true
    rdb_backup_enabled    = var.redis_sku == "Premium" ? true : false
  }

  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 2
  }
}

# ---------------------------------------------------------------------------
# Private Endpoint — Redis
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-redis-${local.prefix}"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_redis_id]
  }
}

# ---------------------------------------------------------------------------
# Key Vault Secrets — Connection Strings
#
# SECURITY NOTE (Redis): The Redis access key is NOT stored in Terraform state
# or in this connection string value. The secret value below contains only the
# hostname and port. The CI/CD pipeline MUST inject the full connection string
# (including the access key) into Key Vault post-deploy using the Key Vault
# Secrets Officer role assignment on the CI/CD identity.
#
# Run the following after `terraform apply`:
#   REDIS_KEY=$(az redis list-keys --name redis-<prefix> --resource-group <rg> \
#               --query primaryKey -o tsv)
#   az keyvault secret set --vault-name <kv> --name RedisConnectionString \
#     --value "<hostname>:6380,password=${REDIS_KEY},ssl=True,abortConnect=False"
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "redis_connection_string" {
  name = "RedisConnectionString"
  # Stores only the endpoint without the access key.
  # The CI/CD pipeline must overwrite this with the full connection string.
  value        = "${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port},ssl=True,abortConnect=False"
  key_vault_id = var.key_vault_id
  tags         = var.tags

  lifecycle {
    # The CI/CD pipeline will update the value with the real access key post-deploy.
    # Prevent Terraform from reverting that update on subsequent applies.
    ignore_changes = [value]
  }
}

# ---------------------------------------------------------------------------
# SQL connection strings use Managed Identity (no password in connection string)
# because azuread_authentication_only = true is enforced on the SQL servers.
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "catalog_connection_string" {
  name         = "CatalogDbConnectionString"
  value        = "Server=tcp:${azurerm_mssql_server.catalog.fully_qualified_domain_name},1433;Initial Catalog=catalogdb;Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = var.key_vault_id
  tags         = var.tags
}

resource "azurerm_key_vault_secret" "identity_connection_string" {
  name         = "IdentityDbConnectionString"
  value        = "Server=tcp:${azurerm_mssql_server.identity.fully_qualified_domain_name},1433;Initial Catalog=identitydb;Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = var.key_vault_id
  tags         = var.tags
}

# ---------------------------------------------------------------------------
# Diagnostic Settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "redis" {
  name                       = "diag-redis-${local.prefix}"
  target_resource_id         = azurerm_redis_cache.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "catalog_db" {
  name                       = "diag-sqldb-catalog-${local.prefix}"
  target_resource_id         = azurerm_mssql_database.catalog.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "AutomaticTuning"
  }

  enabled_log {
    category = "QueryStoreRuntimeStatistics"
  }

  enabled_log {
    category = "QueryStoreWaitStatistics"
  }

  enabled_log {
    category = "Errors"
  }

  enabled_log {
    category = "DatabaseWaitStatistics"
  }

  enabled_log {
    category = "Timeouts"
  }

  enabled_log {
    category = "Blocks"
  }

  metric {
    category = "Basic"
    enabled  = true
  }

  metric {
    category = "InstanceAndAppAdvanced"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "identity_db" {
  name                       = "diag-sqldb-identity-${local.prefix}"
  target_resource_id         = azurerm_mssql_database.identity.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "Errors"
  }

  enabled_log {
    category = "Timeouts"
  }

  metric {
    category = "Basic"
    enabled  = true
  }
}
