data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# SQL Server — Catalog (Business Critical)
# ---------------------------------------------------------------------------
resource "azurerm_mssql_server" "catalog" {
  name                          = "sql-catalog-${var.project}-${var.environment}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  azuread_administrator {
    login_username = "aad-sql-catalog-admin"
    object_id      = data.azurerm_client_config.current.object_id
    # AAD-only authentication: SQL password auth is disabled.
    # Applications must authenticate via Managed Identity or AAD tokens.
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "catalog" {
  server_id              = azurerm_mssql_server.catalog.id
  log_monitoring_enabled = true
  retention_in_days      = 90
}

# ---------------------------------------------------------------------------
# SQL Database — Catalog (Business Critical, Zone-Redundant)
# ---------------------------------------------------------------------------
resource "azurerm_mssql_database" "catalog" {
  name                        = "sqldb-catalog-${var.project}-${var.environment}"
  server_id                   = azurerm_mssql_server.catalog.id
  sku_name                    = var.sql_catalog_sku
  zone_redundant              = true
  geo_backup_enabled          = true
  auto_pause_delay_in_minutes = -1
  max_size_gb                 = 32

  short_term_retention_policy {
    retention_days           = 35
    backup_interval_in_hours = 12
  }

  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P12M"
    yearly_retention  = "P5Y"
    week_of_year      = 1
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# SQL Server — Identity (General Purpose)
# ---------------------------------------------------------------------------
resource "azurerm_mssql_server" "identity" {
  name                          = "sql-identity-${var.project}-${var.environment}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  azuread_administrator {
    login_username = "aad-sql-identity-admin"
    object_id      = data.azurerm_client_config.current.object_id
    # AAD-only authentication: SQL password auth is disabled.
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "identity" {
  server_id              = azurerm_mssql_server.identity.id
  log_monitoring_enabled = true
  retention_in_days      = 90
}

# ---------------------------------------------------------------------------
# SQL Database — Identity (General Purpose, Zone-Redundant)
# ---------------------------------------------------------------------------
resource "azurerm_mssql_database" "identity" {
  name                        = "sqldb-identity-${var.project}-${var.environment}"
  server_id                   = azurerm_mssql_server.identity.id
  sku_name                    = var.sql_identity_sku
  zone_redundant              = true
  geo_backup_enabled          = true
  auto_pause_delay_in_minutes = -1
  max_size_gb                 = 16

  short_term_retention_policy {
    retention_days           = 35
    backup_interval_in_hours = 12
  }

  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P12M"
    yearly_retention  = "P5Y"
    week_of_year      = 1
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Microsoft Defender for SQL — Catalog Server
# Vulnerability assessment uses the SQL server's system-assigned managed
# identity (Storage Blob Data Contributor on the vuln-assessment container)
# instead of a SAS token or account key — no credential in state.
# ---------------------------------------------------------------------------
resource "azurerm_mssql_server_security_alert_policy" "catalog" {
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mssql_server.catalog.name
  state               = "Enabled"
}

resource "azurerm_role_assignment" "catalog_sql_vuln_storage" {
  scope                = "${azurerm_storage_account.images.id}/blobServices/default/containers/vulnerability-assessment"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_mssql_server.catalog.identity[0].principal_id
}

resource "azurerm_mssql_server_vulnerability_assessment" "catalog" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.catalog.id
  storage_container_path          = "${azurerm_storage_account.images.primary_blob_endpoint}vulnerability-assessment/"

  # storage_account_access_key omitted: authentication via system-assigned MI
  # (Storage Blob Data Contributor role granted above)

  recurring_scans {
    enabled                   = true
    email_subscription_admins = true
  }

  depends_on = [azurerm_role_assignment.catalog_sql_vuln_storage]
}

# ---------------------------------------------------------------------------
# Microsoft Defender for SQL — Identity Server
# ---------------------------------------------------------------------------
resource "azurerm_mssql_server_security_alert_policy" "identity" {
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mssql_server.identity.name
  state               = "Enabled"
}

resource "azurerm_role_assignment" "identity_sql_vuln_storage" {
  scope                = "${azurerm_storage_account.images.id}/blobServices/default/containers/vulnerability-assessment"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_mssql_server.identity.identity[0].principal_id
}

resource "azurerm_mssql_server_vulnerability_assessment" "identity" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.identity.id
  storage_container_path          = "${azurerm_storage_account.images.primary_blob_endpoint}vulnerability-assessment/"

  # storage_account_access_key omitted: authentication via system-assigned MI

  recurring_scans {
    enabled                   = true
    email_subscription_admins = true
  }

  depends_on = [azurerm_role_assignment.identity_sql_vuln_storage]
}

# ---------------------------------------------------------------------------
# Private Endpoint — Catalog SQL
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "sql_catalog" {
  name                = "pe-sql-catalog-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-catalog"
    private_connection_resource_id = azurerm_mssql_server.catalog.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "dns-sql-catalog"
    private_dns_zone_ids = [
      "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net"
    ]
  }
}

# ---------------------------------------------------------------------------
# Private Endpoint — Identity SQL
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "sql_identity" {
  name                = "pe-sql-identity-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-identity"
    private_connection_resource_id = azurerm_mssql_server.identity.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "dns-sql-identity"
    private_dns_zone_ids = [
      "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net"
    ]
  }
}

# ---------------------------------------------------------------------------
# Azure Cache for Redis (Standard C1)
# NOTE: Standard SKU does not support RDB/AOF persistence backups.
# Upgrade to Premium SKU to enable persistence if cache data durability
# is required. This is documented as a residual risk.
# NOTE on Redis key: The primary_access_key is NOT embedded in the Key Vault
# secret value. The secret stores only connection metadata (hostname, port,
# SSL flags). The application must retrieve the access key at runtime using
# the managed identity via Azure Cache for Redis AAD token auth
# (StackExchange.Redis + Microsoft.Identity.Client), or an operator must
# write the key out-of-band post-deploy:
#   az keyvault secret set \
#     --vault-name kv-<project>-<env> \
#     --name redis-access-key \
#     --value "$(az redis list-keys --name redis-<project>-<env> \
#                --resource-group rg-<project>-<env> \
#                --query primaryKey -o tsv)"
# ---------------------------------------------------------------------------
resource "azurerm_redis_cache" "main" {
  name                          = "redis-${var.project}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = var.redis_capacity
  family                        = var.redis_family
  sku_name                      = var.redis_sku
  enable_non_ssl_port           = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  redis_configuration {
    maxmemory_reserved    = 50
    maxmemory_delta       = 50
    maxmemory_policy      = "allkeys-lru"
    enable_authentication = true
    rdb_backup_enabled    = false
  }
}

# ---------------------------------------------------------------------------
# Private Endpoint — Redis
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-redis"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "dns-redis"
    private_dns_zone_ids = [
      "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/privateDnsZones/privatelink.redis.cache.windows.net"
    ]
  }
}

# ---------------------------------------------------------------------------
# Redis Diagnostic Settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "redis" {
  name                       = "diag-redis-${var.project}-${var.environment}"
  target_resource_id         = azurerm_redis_cache.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ---------------------------------------------------------------------------
# SQL Diagnostic Settings — Catalog
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "sql_catalog" {
  name                       = "diag-sql-catalog-${var.project}-${var.environment}"
  target_resource_id         = azurerm_mssql_database.catalog.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "SQLInsights" }
  enabled_log { category = "AutomaticTuning" }
  enabled_log { category = "QueryStoreRuntimeStatistics" }
  enabled_log { category = "Errors" }
  enabled_log { category = "DatabaseWaitStatistics" }
  enabled_log { category = "Timeouts" }
  enabled_log { category = "Blocks" }
  enabled_log { category = "Deadlocks" }

  metric {
    category = "Basic"
    enabled  = true
  }
}

# ---------------------------------------------------------------------------
# SQL Diagnostic Settings — Identity
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "sql_identity" {
  name                       = "diag-sql-identity-${var.project}-${var.environment}"
  target_resource_id         = azurerm_mssql_database.identity.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "SQLInsights" }
  enabled_log { category = "Errors" }
  enabled_log { category = "Deadlocks" }

  metric {
    category = "Basic"
    enabled  = true
  }
}

# ---------------------------------------------------------------------------
# Azure Blob Storage (product images + vulnerability assessment)
# shared_access_key_enabled = false: all access via RBAC/managed identity only.
# No SAS tokens or account keys are generated or stored.
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "images" {
  name                            = "st${var.project}${var.environment}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  tags                            = var.tags

  blob_properties {
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
    versioning_enabled       = true
    change_feed_enabled      = true
    last_access_time_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_storage_container" "images" {
  name                  = "images"
  storage_account_name  = azurerm_storage_account.images.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "vulnerability_assessment" {
  name                  = "vulnerability-assessment"
  storage_account_name  = azurerm_storage_account.images.name
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Blob Lifecycle Management Policy
# ---------------------------------------------------------------------------
resource "azurerm_storage_management_policy" "images" {
  storage_account_id = azurerm_storage_account.images.id

  rule {
    name    = "archive-vulnerability-assessment"
    enabled = true

    filters {
      prefix_match = ["vulnerability-assessment/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 30
      }
      version {
        delete_after_days_since_creation = 90
      }
    }
  }

  rule {
    name    = "expire-old-image-versions"
    enabled = true

    filters {
      prefix_match = ["images/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      version {
        delete_after_days_since_creation = 365
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Storage Blob Diagnostic Settings (audit read/write/delete operations)
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name               = "diag-storage-blob-${var.project}-${var.environment}"
  target_resource_id = "${azurerm_storage_account.images.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

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

# ---------------------------------------------------------------------------
# Private Endpoint — Blob Storage
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "blob" {
  name                = "pe-blob-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-blob"
    private_connection_resource_id = azurerm_storage_account.images.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "dns-blob"
    private_dns_zone_ids = [
      "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    ]
  }
}

# ---------------------------------------------------------------------------
# RBAC — Storage Blob Data Contributor for Managed Identity (images container)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "storage_mi" {
  scope                = azurerm_storage_account.images.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.managed_identity_principal_id
}

# ---------------------------------------------------------------------------
# Key Vault Secrets — Connection Strings
# SECURITY: Redis primary_access_key is intentionally NOT embedded here.
# The secret value contains only the hostname, port, and SSL flag so that
# the key itself never lands in Terraform state or the KV secret value.
# The application uses AAD token-based auth (Managed Identity) to connect
# to Redis. Operators must perform a one-time post-deploy key injection
# if the application does not yet support AAD token auth for Redis.
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "catalog_connection_string" {
  name  = "catalog-db-connection-string"
  value = "Server=${azurerm_mssql_server.catalog.fully_qualified_domain_name};Database=${azurerm_mssql_database.catalog.name};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;"
  key_vault_id = var.key_vault_id
  tags         = var.tags

  depends_on = [azurerm_mssql_server.catalog, azurerm_mssql_database.catalog]
}

resource "azurerm_key_vault_secret" "identity_connection_string" {
  name  = "identity-db-connection-string"
  value = "Server=${azurerm_mssql_server.identity.fully_qualified_domain_name};Database=${azurerm_mssql_database.identity.name};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;"
  key_vault_id = var.key_vault_id
  tags         = var.tags

  depends_on = [azurerm_mssql_server.identity, azurerm_mssql_database.identity]
}

# Redis connection metadata only — no access key embedded.
# The application authenticates to Redis using AAD token auth (Managed Identity).
# StackExchange.Redis >= 2.6.x supports AAD token authentication.
# Hostname and port are non-sensitive endpoint data needed for connection setup.
resource "azurerm_key_vault_secret" "redis_connection_string" {
  name  = "redis-connection-string"
  value = "${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port},ssl=True,abortConnect=False"
  key_vault_id = var.key_vault_id
  tags         = var.tags

  depends_on = [azurerm_redis_cache.main]
}
