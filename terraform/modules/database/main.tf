# ---------------------------------------------------------------------------
# Database Module — Azure SQL (Catalog + Identity), Redis Cache,
#                   Blob Storage, Private Endpoints, Diagnostics
# ---------------------------------------------------------------------------

data "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
}

# ---------------------------------------------------------------------------
# Catalog SQL Logical Server
# ---------------------------------------------------------------------------
resource "azurerm_mssql_server" "catalog" {
  name                          = "sql-catalog-${var.name_prefix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  azuread_administrator {
    login_username              = "AzureAD Admin"
    object_id                   = var.sql_aad_admin_object_id
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }
}

# Catalog SQL Database
resource "azurerm_mssql_database" "catalog" {
  name                        = "catalogDb"
  server_id                   = azurerm_mssql_server.catalog.id
  sku_name                    = var.catalog_db_sku
  max_size_gb                 = 32
  auto_pause_delay_in_minutes = 60
  min_capacity                = 0.5
  read_scale                  = false
  zone_redundant              = false
  tags                        = var.tags

  threat_detection_policy {
    state                = "Enabled"
    email_account_admins = true
    retention_days       = 30
  }

  short_term_retention_policy {
    retention_days           = 7
    backup_interval_in_hours = 12
  }

  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P0W"
    yearly_retention  = "P0Y"
    week_of_year      = 0
  }

  transparent_data_encryption_key_automatic_rotation_enabled = true
}

# Catalog SQL — Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "catalog_sql" {
  name                       = "diag-sql-catalog-${var.name_prefix}"
  target_resource_id         = azurerm_mssql_database.catalog.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "QueryStoreRuntimeStatistics"
  }

  metric {
    category = "Basic"
    enabled  = true
  }
}

# Catalog SQL — Auditing
resource "azurerm_mssql_server_extended_auditing_policy" "catalog" {
  server_id              = azurerm_mssql_server.catalog.id
  log_monitoring_enabled = true
  retention_in_days      = 90
}

# Catalog SQL — Defender for SQL: Security Alert Policy
resource "azurerm_mssql_server_security_alert_policy" "catalog" {
  server_name         = azurerm_mssql_server.catalog.name
  resource_group_name = var.resource_group_name
  state               = "Enabled"
  email_account_admins = true
  retention_days      = 30
}

# Catalog SQL — Defender for SQL: Vulnerability Assessment
resource "azurerm_mssql_server_vulnerability_assessment" "catalog" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.catalog.id
  storage_container_path          = "${azurerm_storage_account.images.primary_blob_endpoint}vulnerability-assessment/"

  recurring_scans {
    enabled                   = true
    email_subscription_admins = true
  }
}

# Private Endpoint — Catalog SQL
resource "azurerm_private_endpoint" "catalog_sql" {
  name                = "pe-sql-catalog-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_data_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-catalog-${var.name_prefix}"
    private_connection_resource_id = azurerm_mssql_server.catalog.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-sql-catalog"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.sql.id]
  }
}

# ---------------------------------------------------------------------------
# Identity SQL Logical Server
# ---------------------------------------------------------------------------
resource "azurerm_mssql_server" "identity" {
  name                          = "sql-identity-${var.name_prefix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  azuread_administrator {
    login_username              = "AzureAD Admin"
    object_id                   = var.sql_aad_admin_object_id
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }
}

# Identity SQL Database
resource "azurerm_mssql_database" "identity" {
  name                        = "identityDb"
  server_id                   = azurerm_mssql_server.identity.id
  sku_name                    = var.identity_db_sku
  max_size_gb                 = 16
  auto_pause_delay_in_minutes = 60
  min_capacity                = 0.5
  read_scale                  = false
  zone_redundant              = false
  tags                        = var.tags

  threat_detection_policy {
    state                = "Enabled"
    email_account_admins = true
    retention_days       = 30
  }

  short_term_retention_policy {
    retention_days           = 7
    backup_interval_in_hours = 12
  }

  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P0W"
    yearly_retention  = "P0Y"
    week_of_year      = 0
  }
}

# Identity SQL — Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "identity_sql" {
  name                       = "diag-sql-identity-${var.name_prefix}"
  target_resource_id         = azurerm_mssql_database.identity.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  enabled_log {
    category = "SQLInsights"
  }

  metric {
    category = "Basic"
    enabled  = true
  }
}

# Identity SQL — Auditing
resource "azurerm_mssql_server_extended_auditing_policy" "identity" {
  server_id              = azurerm_mssql_server.identity.id
  log_monitoring_enabled = true
  retention_in_days      = 90
}

# Identity SQL — Defender for SQL: Security Alert Policy
resource "azurerm_mssql_server_security_alert_policy" "identity" {
  server_name         = azurerm_mssql_server.identity.name
  resource_group_name = var.resource_group_name
  state               = "Enabled"
  email_account_admins = true
  retention_days      = 30
}

# Identity SQL — Defender for SQL: Vulnerability Assessment
resource "azurerm_mssql_server_vulnerability_assessment" "identity" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.identity.id
  storage_container_path          = "${azurerm_storage_account.images.primary_blob_endpoint}vulnerability-assessment/"

  recurring_scans {
    enabled                   = true
    email_subscription_admins = true
  }
}

# Private Endpoint — Identity SQL
resource "azurerm_private_endpoint" "identity_sql" {
  name                = "pe-sql-identity-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_data_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-identity-${var.name_prefix}"
    private_connection_resource_id = azurerm_mssql_server.identity.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-sql-identity"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.sql.id]
  }
}

# ---------------------------------------------------------------------------
# Azure Cache for Redis
# ---------------------------------------------------------------------------
resource "azurerm_redis_cache" "main" {
  name                          = "redis-${var.name_prefix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = var.redis_capacity
  family                        = var.redis_family
  sku_name                      = var.redis_sku_name
  enable_non_ssl_port           = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  redis_configuration {
    maxmemory_reserved     = 50
    maxmemory_delta        = 50
    maxmemory_policy       = "allkeys-lru"
    notify_keyspace_events = ""
  }

  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 2
  }
}

# Private Endpoint — Redis
resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_data_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-redis-${var.name_prefix}"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-redis"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.redis.id]
  }
}

# Redis — Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "redis" {
  name                       = "diag-redis-${var.name_prefix}"
  target_resource_id         = azurerm_redis_cache.main.id
  log_analytics_workspace_id = var.log_analytics_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ---------------------------------------------------------------------------
# Azure Blob Storage — Product Images
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "images" {
  name                            = "st${replace(var.name_prefix, "-", "")}imgs"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  account_kind                    = "StorageV2"
  access_tier                     = "Hot"
  enable_https_traffic_only       = true
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  infrastructure_encryption_enabled = true
  tags                            = var.tags

  identity {
    type = "SystemAssigned"
  }

  blob_properties {
    versioning_enabled       = true
    change_feed_enabled      = true
    last_access_time_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

# Storage account — Customer-Managed Key (CMK) via Key Vault
resource "azurerm_storage_account_customer_managed_key" "images" {
  storage_account_id = azurerm_storage_account.images.id
  key_vault_id       = var.key_vault_id
  key_name           = split("/", var.key_vault_key_id)[length(split("/", var.key_vault_key_id)) - 3]
}

resource "azurerm_storage_container" "images" {
  name                  = "product-images"
  storage_account_name  = azurerm_storage_account.images.name
  container_access_type = "private"
}

# Private Endpoint — Blob Storage
resource "azurerm_private_endpoint" "blob" {
  name                = "pe-blob-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_data_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-blob-${var.name_prefix}"
    private_connection_resource_id = azurerm_storage_account.images.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-blob"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.blob.id]
  }
}

# Storage — Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "diag-storage-${var.name_prefix}"
  target_resource_id         = "${azurerm_storage_account.images.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
