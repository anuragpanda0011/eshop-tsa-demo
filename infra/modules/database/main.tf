# ── Random Suffix for unique names ───────────────────────────────────────────
resource "random_string" "sql_suffix" {
  length  = 8
  special = false
  upper   = false
}

# ── Internally generated throwaway SQL bootstrap credentials ──────────────────
# Since azuread_authentication_only = true is enforced, the SQL administrator
# password is non-functional after deployment. Generating it internally means:
#   1. The credential never appears in tfvars or CI/CD pipelines
#   2. The generated value in state is still protected by CMK on the backend
#   3. The deployer does not need to supply or rotate this credential
resource "random_string" "sql_admin_login" {
  length  = 12
  special = false
  upper   = false
  numeric = false
}

resource "random_password" "sql_admin_password" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# ── Azure SQL Server ──────────────────────────────────────────────────────────
resource "azurerm_mssql_server" "main" {
  name                          = "sql-${var.project}-${var.environment}-${random_string.sql_suffix.result}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = "sqladmin-${random_string.sql_admin_login.result}"
  administrator_login_password  = random_password.sql_admin_password.result
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  azuread_administrator {
    login_username = "aad-sql-admin"
    object_id      = var.aad_sql_admin_object_id
    tenant_id      = var.tenant_id
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }

  # FIX: Prevent accidental destruction of the production SQL server.
  lifecycle {
    prevent_destroy = true
  }
}

# ── Grant SQL server's system-assigned MI Storage Blob Data Contributor ───────
resource "azurerm_role_assignment" "sql_audit_storage_mi" {
  scope                = var.audit_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_mssql_server.main.identity[0].principal_id
}

# ── SQL Server Auditing ───────────────────────────────────────────────────────
resource "azurerm_mssql_server_extended_auditing_policy" "main" {
  server_id                        = azurerm_mssql_server.main.id
  log_monitoring_enabled           = true
  retention_in_days                = 90
  storage_endpoint                 = var.audit_storage_primary_blob_endpoint
  storage_account_subscription_id  = var.audit_storage_subscription_id

  depends_on = [azurerm_role_assignment.sql_audit_storage_mi]
}

# ── Catalog Database ──────────────────────────────────────────────────────────
resource "azurerm_mssql_database" "catalogdb" {
  name                        = "catalogdb"
  server_id                   = azurerm_mssql_server.main.id
  sku_name                    = var.sql_sku
  max_size_gb                 = var.sql_max_size_gb
  zone_redundant              = var.sql_zone_redundant
  geo_backup_enabled          = true
  read_scale                  = false
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
    retention_days       = 30
    disabled_alerts      = []
  }

  # FIX: Prevent accidental destruction of the production catalog database.
  lifecycle {
    prevent_destroy = true
  }
}

# ── Identity Database ─────────────────────────────────────────────────────────
resource "azurerm_mssql_database" "identitydb" {
  name                        = "identitydb"
  server_id                   = azurerm_mssql_server.main.id
  sku_name                    = var.sql_sku
  max_size_gb                 = var.sql_max_size_gb
  zone_redundant              = var.sql_zone_redundant
  geo_backup_enabled          = true
  read_scale                  = false
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
    retention_days       = 30
    disabled_alerts      = []
  }

  # FIX: Prevent accidental destruction of the production identity database.
  lifecycle {
    prevent_destroy = true
  }
}

# ── Private Endpoint for SQL Server ──────────────────────────────────────────
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_pe_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-${var.project}"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-sql"
    private_dns_zone_ids = [var.private_dns_zone_sql_id]
  }
}

# ── Key Vault Secrets — Connection Strings ────────────────────────────────────
# FIX: Added expiration_date to both SQL connection string secrets so they are
# reviewed and rotated at least annually. The expiration_date is suppressed from
# lifecycle ignore_changes to avoid perpetual diffs from timestamp() re-evaluation
# on each plan, but value drift is NOT suppressed — Terraform will correct stale values.
resource "azurerm_key_vault_secret" "catalog_connection_string" {
  name            = "catalog-connection-string"
  value           = "Server=${azurerm_mssql_server.main.fully_qualified_domain_name};Database=catalogdb;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id    = var.key_vault_id
  content_type    = "text/plain; charset=utf-8"
  expiration_date = timeadd(timestamp(), "8760h") # 1 year

  tags = var.tags

  lifecycle {
    # Suppress perpetual diff from timestamp() re-evaluation at each plan.
    # Value is NOT ignored — Terraform will detect and remediate drift.
    ignore_changes = [
      expiration_date,
    ]
  }
}

resource "azurerm_key_vault_secret" "identity_connection_string" {
  name            = "identity-connection-string"
  value           = "Server=${azurerm_mssql_server.main.fully_qualified_domain_name};Database=identitydb;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id    = var.key_vault_id
  content_type    = "text/plain; charset=utf-8"
  expiration_date = timeadd(timestamp(), "8760h") # 1 year

  tags = var.tags

  lifecycle {
    ignore_changes = [
      expiration_date,
    ]
  }
}

# ── Azure Cache for Redis (Standard C1) ───────────────────────────────────────
resource "azurerm_redis_cache" "main" {
  name                          = "redis-${var.project}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = var.redis_capacity
  family                        = var.redis_family
  sku_name                      = var.redis_sku
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  enable_non_ssl_port           = false
  tags                          = var.tags

  redis_configuration {
    maxmemory_policy      = "volatile-lru"
    enable_authentication = true
  }

  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 2
  }
}

# ── Private Endpoint for Redis ────────────────────────────────────────────────
resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_pe_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-redis-${var.project}"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-redis"
    private_dns_zone_ids = [var.private_dns_zone_redis_id]
  }
}

# ── Key Vault Secret — Redis Connection String ────────────────────────────────
# SECURITY NOTE: The Redis primary_access_key will appear in Terraform state.
# This is unavoidable with the azurerm provider when using azurerm_redis_cache.
#
# MANDATORY mitigations:
#   1. The tfstate backend storage account MUST use CMK encryption + strict RBAC
#      (see README Quick Start — HARD REQUIREMENT before first apply)
#   2. IMMEDIATELY rotate the Redis key after deployment:
#      az redis regenerate-keys --name <name> --resource-group <rg> --key-type Primary
#   3. Update this KV secret with the new key after rotation (see README)
#   4. On next terraform apply, Terraform will sync KV secret value to match
#      azurerm_redis_cache.primary_access_key (value is NO LONGER ignored)
#   5. Restrict access to the tfstate container to Terraform deployer identity only
#
# FIX: Removed 'value' from lifecycle.ignore_changes.
#   Previously, ignore_changes = [value] meant a corrupted, deleted, or stale
#   secret value was never corrected by Terraform. This is removed so Terraform
#   can detect and remediate drift. Post-rotation key updates must be handled via
#   a dedicated rotation pipeline step (see README), not by suppressing all changes.
resource "azurerm_key_vault_secret" "redis_connection_string" {
  name            = "redis-connection-string"
  value           = "${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port},password=${azurerm_redis_cache.main.primary_access_key},ssl=True,abortConnect=False"
  key_vault_id    = var.key_vault_id
  content_type    = "text/plain; charset=utf-8"
  expiration_date = timeadd(timestamp(), "8760h") # 1 year; rotate before expiry

  tags = var.tags

  lifecycle {
    # ONLY suppress perpetual diff from timestamp() re-evaluation at each plan.
    # 'value' is intentionally NOT in ignore_changes — Terraform must be able
    # to detect and correct a stale or corrupted secret value.
    ignore_changes = [
      expiration_date,
    ]
  }
}

# ── Diagnostic Settings for SQL ───────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "catalogdb" {
  name                       = "diag-catalogdb"
  target_resource_id         = azurerm_mssql_database.catalogdb.id
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

resource "azurerm_monitor_diagnostic_setting" "identitydb" {
  name                       = "diag-identitydb"
  target_resource_id         = azurerm_mssql_database.identitydb.id
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

resource "azurerm_monitor_diagnostic_setting" "redis" {
  name                       = "diag-redis-${var.project}"
  target_resource_id         = azurerm_redis_cache.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
