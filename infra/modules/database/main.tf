###############################################################################
# Azure SQL Server — Catalog
# administrator_login / administrator_login_password are intentionally omitted:
# azuread_authentication_only = true disables password auth entirely so the
# azurerm provider does not require these fields and no SQL credential lands
# in Terraform state.
###############################################################################
resource "azurerm_mssql_server" "catalog" {
  name                          = var.sql_catalog_server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  azuread_administrator {
    login_username              = var.entra_sql_admin_login
    object_id                   = var.entra_sql_admin_object_id
    # Entra-only: password-based SQL logins are fully disabled
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }
}

###############################################################################
# Catalog Database
###############################################################################
resource "azurerm_mssql_database" "catalog" {
  name                        = var.sql_catalog_db_name
  server_id                   = azurerm_mssql_server.catalog.id
  sku_name                    = var.sql_catalog_sku
  zone_redundant              = true
  geo_backup_enabled          = true
  max_size_gb                 = 128
  read_scale                  = true
  storage_account_type        = "Geo"
  tags                        = var.tags

  short_term_retention_policy {
    retention_days           = var.sql_backup_retention_days
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
    retention_days       = 30
  }
}

###############################################################################
# Catalog SQL Server — Auditing (Log Analytics only; no storage key in state)
###############################################################################
resource "azurerm_mssql_server_extended_auditing_policy" "catalog" {
  server_id              = azurerm_mssql_server.catalog.id
  log_monitoring_enabled = true
  # retention_in_days intentionally omitted — Log Analytics controls retention
}

###############################################################################
# Azure SQL Server — Identity
###############################################################################
resource "azurerm_mssql_server" "identity" {
  name                          = var.sql_identity_server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  azuread_administrator {
    login_username              = var.entra_sql_admin_login
    object_id                   = var.entra_sql_admin_object_id
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }
}

###############################################################################
# Identity Database
###############################################################################
resource "azurerm_mssql_database" "identity" {
  name                 = var.sql_identity_db_name
  server_id            = azurerm_mssql_server.identity.id
  sku_name             = var.sql_identity_sku
  zone_redundant       = true
  geo_backup_enabled   = true
  max_size_gb          = 32
  storage_account_type = "Geo"
  tags                 = var.tags

  short_term_retention_policy {
    retention_days           = var.sql_backup_retention_days
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
    retention_days       = 30
  }
}

###############################################################################
# Identity SQL Server — Auditing (Log Analytics only)
###############################################################################
resource "azurerm_mssql_server_extended_auditing_policy" "identity" {
  server_id              = azurerm_mssql_server.identity.id
  log_monitoring_enabled = true
  # retention_in_days intentionally omitted — Log Analytics controls retention
}

###############################################################################
# Private Endpoints — SQL Servers
###############################################################################
resource "azurerm_private_endpoint" "sql_catalog" {
  name                = "pe-sql-catalog-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.sql_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-catalog"
    private_connection_resource_id = azurerm_mssql_server.catalog.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-catalog-dns-group"
    private_dns_zone_ids = [var.sql_private_dns_zone_id]
  }
}

resource "azurerm_private_endpoint" "sql_identity" {
  name                = "pe-sql-identity-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.sql_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-identity"
    private_connection_resource_id = azurerm_mssql_server.identity.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-identity-dns-group"
    private_dns_zone_ids = [var.sql_private_dns_zone_id]
  }
}

###############################################################################
# Storage Account for Redis RDB backups
###############################################################################
resource "azurerm_storage_account" "redis_backup" {
  name                     = "st${replace(var.redis_name, "-", "")}bkp"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  # Disable shared key access; Redis uses managed identity
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  tags                            = var.tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }
}

###############################################################################
# RBAC — Redis cache managed identity → Storage Blob Data Contributor
# This allows Redis to write RDB backups without a storage key.
###############################################################################
resource "azurerm_role_assignment" "redis_backup_storage" {
  scope                = azurerm_storage_account.redis_backup.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_redis_cache.main.identity[0].principal_id
}

###############################################################################
# Azure Cache for Redis — Premium P1
###############################################################################
resource "azurerm_redis_cache" "main" {
  name                          = var.redis_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = var.redis_capacity
  family                        = var.redis_family
  sku_name                      = var.redis_sku_name
  enable_non_ssl_port           = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  # System-assigned identity required for managed-identity backup
  identity {
    type = "SystemAssigned"
  }

  redis_configuration {
    enable_authentication           = true
    maxmemory_policy                = "allkeys-lru"
    maxmemory_reserved              = 50
    maxfragmentationmemory_reserved = 50
  }

  zones = ["1", "2", "3"]

  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 2
  }
}

###############################################################################
# Private Endpoint — Redis
###############################################################################
resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.redis_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-redis"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis-dns-group"
    private_dns_zone_ids = [var.redis_private_dns_zone_id]
  }
}

###############################################################################
# Diagnostic Settings
###############################################################################
resource "azurerm_monitor_diagnostic_setting" "redis" {
  name                       = "diag-redis-${var.environment}"
  target_resource_id         = azurerm_redis_cache.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # ConnectedClientList captures connection anomalies and auth failures
  enabled_log {
    category = "ConnectedClientList"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "sql_catalog_db" {
  name                       = "diag-sql-catalog-${var.environment}"
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
  enabled_log {
    category = "Deadlocks"
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

resource "azurerm_monitor_diagnostic_setting" "sql_identity_db" {
  name                       = "diag-sql-identity-${var.environment}"
  target_resource_id         = azurerm_mssql_database.identity.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "SQLInsights"
  }
  enabled_log {
    category = "Errors"
  }
  enabled_log {
    category = "Deadlocks"
  }

  metric {
    category = "Basic"
    enabled  = true
  }
}
