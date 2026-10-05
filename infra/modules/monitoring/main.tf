# ── Log Analytics Workspace (via data source — created by monitoring_bootstrap) ─
data "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
}

# ── CMK Storage Account for Log Analytics Workspace ───────────────────────────
resource "azurerm_storage_account" "law_cmk" {
  name                            = "stlaw${var.project}${var.environment}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  tags                            = var.tags

  identity {
    type = "SystemAssigned"
  }

  # FIX: Added blob_properties for versioning and soft-delete — consistent with
  # all other storage accounts in the project. Without this, LAW CMK storage blobs
  # can be accidentally deleted or overwritten with no recovery path.
  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

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

# Grant the LAW CMK storage account's system identity Key Vault Crypto User
resource "azurerm_role_assignment" "law_cmk_storage_kv_crypto" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azurerm_storage_account.law_cmk.identity[0].principal_id
}

# Configure CMK on the LAW storage account
resource "azurerm_storage_account_customer_managed_key" "law_cmk" {
  storage_account_id = azurerm_storage_account.law_cmk.id
  key_vault_id       = var.key_vault_id
  key_name           = var.data_protection_key_name

  depends_on = [azurerm_role_assignment.law_cmk_storage_kv_crypto]
}

# ── Private Endpoint for LAW CMK Storage Account ──────────────────────────────
resource "azurerm_private_endpoint" "law_cmk_storage" {
  name                = "pe-stlaw-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_pe_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-stlaw-${var.project}"
    private_connection_resource_id = azurerm_storage_account.law_cmk.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-stlaw-blob"
    private_dns_zone_ids = [var.private_dns_zone_blob_id]
  }

  depends_on = [azurerm_storage_account_customer_managed_key.law_cmk]
}

# Link the CMK storage account to the Log Analytics workspace (CustomLogs)
resource "azurerm_log_analytics_linked_storage_account" "law_cmk" {
  data_source_type      = "CustomLogs"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = data.azurerm_log_analytics_workspace.main.id
  storage_account_ids   = [azurerm_storage_account.law_cmk.id]

  depends_on = [
    azurerm_storage_account_customer_managed_key.law_cmk,
    azurerm_private_endpoint.law_cmk_storage,
  ]
}

resource "azurerm_log_analytics_linked_storage_account" "law_cmk_query" {
  data_source_type      = "Query"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = data.azurerm_log_analytics_workspace.main.id
  storage_account_ids   = [azurerm_storage_account.law_cmk.id]

  depends_on = [
    azurerm_storage_account_customer_managed_key.law_cmk,
    azurerm_private_endpoint.law_cmk_storage,
  ]
}

# ── Application Insights (Workspace-based) ────────────────────────────────────
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = data.azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  retention_in_days   = var.log_retention_days
  sampling_percentage = var.sampling_percentage
  # FIX: Disable local (instrumentation key) authentication.
  # The instrumentation_key is a shared secret that grants unauthenticated write
  # access to the App Insights instance. Disabling it forces all ingestion through
  # AAD-authenticated channels using the connection_string only.
  local_authentication_disabled = true
  tags                          = var.tags
}

# ── Action Group (alerts → email) ─────────────────────────────────────────────
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "eshop-ops"
  tags                = var.tags

  email_receiver {
    name                    = "OpsEmail"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# ── Metric Alert: High CPU on Container App Environment ───────────────────────
resource "azurerm_monitor_metric_alert" "cpu_high" {
  name                = "alert-cpu-high-${var.project}"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"]
  description         = "Alert when CPU usage is consistently high"
  severity            = 2
  window_size         = "PT5M"
  frequency           = "PT1M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "CpuUsageNanoCores"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 800000000
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ── Metric Alert: High Memory ─────────────────────────────────────────────────
resource "azurerm_monitor_metric_alert" "memory_high" {
  name                = "alert-memory-high-${var.project}"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"]
  description         = "Alert when memory usage is high"
  severity            = 2
  window_size         = "PT5M"
  frequency           = "PT1M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "MemoryWorkingSetBytes"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 1610612736
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ── Metric Alert: SQL DTU / CPU high ─────────────────────────────────────────
resource "azurerm_monitor_metric_alert" "sql_cpu_high" {
  name                = "alert-sql-cpu-${var.project}"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"]
  description         = "Alert when SQL CPU percentage is high"
  severity            = 2
  window_size         = "PT15M"
  frequency           = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ── Metric Alert: Redis memory ────────────────────────────────────────────────
resource "azurerm_monitor_metric_alert" "redis_memory" {
  name                = "alert-redis-memory-${var.project}"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"]
  description         = "Alert when Redis used memory is high"
  severity            = 2
  window_size         = "PT15M"
  frequency           = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Cache/Redis"
    metric_name      = "usedmemorypercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ── Metric Alert: Log Analytics Daily Data Cap ────────────────────────────────
resource "azurerm_monitor_metric_alert" "law_data_cap" {
  name                = "alert-law-datacap-${var.project}"
  resource_group_name = var.resource_group_name
  scopes              = [data.azurerm_log_analytics_workspace.main.id]
  description         = "Alert when Log Analytics daily data cap is approaching — logs may be dropped"
  severity            = 1
  window_size         = "PT1H"
  frequency           = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.OperationalInsights/workspaces"
    metric_name      = "DataCollectionThrottling"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ── Application Insights Availability Test ────────────────────────────────────
resource "azurerm_application_insights_standard_web_test" "health" {
  name                    = "webtest-health-${var.project}"
  resource_group_name     = var.resource_group_name
  location                = var.location
  application_insights_id = azurerm_application_insights.main.id
  geo_locations           = ["us-ca-sjc-azr", "us-tx-sn1-azr", "us-il-ch1-azr", "us-va-ash-azr", "us-fl-mia-edge"]
  description             = "Health endpoint availability test"
  enabled                 = true
  frequency               = 300
  timeout                 = 30
  retry_enabled           = true
  tags                    = var.tags

  request {
    url                              = "https://${var.health_check_url}/health"
    http_verb                        = "GET"
    parse_dependent_requests_enabled = false
  }

  validation_rules {
    expected_status_code        = 200
    ssl_check_enabled           = true
    ssl_cert_remaining_lifetime = 14
  }
}

resource "azurerm_monitor_metric_alert" "availability_test" {
  name                = "alert-availability-${var.project}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when web availability drops"
  severity            = 1
  window_size         = "PT5M"
  frequency           = "PT1M"
  tags                = var.tags

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.health.id
    component_id          = azurerm_application_insights.main.id
    failed_location_count = 2
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ── Azure Monitor Workbook (Custom Dashboard) ─────────────────────────────────
resource "azurerm_application_insights_workbook" "main" {
  name                = "wb-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "eShopOnWeb Operations Dashboard"
  source_id           = lower(azurerm_application_insights.main.id)
  tags                = var.tags

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "# eShopOnWeb Operations Dashboard\n\nReal-time monitoring for eShopOnWeb production environment."
        }
        name = "header"
      },
      {
        type = 3
        content = {
          version      = "KqlItem/1.0"
          query        = "requests | summarize count() by bin(timestamp, 5m) | render timechart"
          size         = 0
          title        = "Request Rate (5-minute buckets)"
          timeContext  = { durationMs = 3600000 }
          queryType    = 0
          resourceType = "microsoft.insights/components"
          crossComponentResources = [azurerm_application_insights.main.id]
        }
        name = "requests-chart"
      },
      {
        type = 3
        content = {
          version      = "KqlItem/1.0"
          query        = "requests | where success == false | summarize count() by bin(timestamp, 5m) | render timechart"
          size         = 0
          title        = "Failed Requests"
          timeContext  = { durationMs = 3600000 }
          queryType    = 0
          resourceType = "microsoft.insights/components"
          crossComponentResources = [azurerm_application_insights.main.id]
        }
        name = "failures-chart"
      }
    ]
    isLocked            = false
    fallbackResourceIds = [azurerm_application_insights.main.id]
  })
}

# ── Log Analytics Saved Searches ───────────────────────────────────────────────
resource "azurerm_log_analytics_saved_search" "failed_requests" {
  name                       = "FailedHttpRequests"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id
  category                   = "eShopOnWeb"
  display_name               = "Failed HTTP Requests"
  query                      = <<-KUSTO
    AppRequests
    | where Success == false
    | summarize count() by ResultCode, Name
    | order by count_ desc
  KUSTO
}

resource "azurerm_log_analytics_saved_search" "slow_queries" {
  name                       = "SlowDatabaseQueries"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id
  category                   = "eShopOnWeb"
  display_name               = "Slow Database Queries (>1s)"
  query                      = <<-KUSTO
    AppDependencies
    | where Type == "SQL"
    | where DurationMs > 1000
    | summarize avg(DurationMs), count() by Name
    | order by avg_DurationMs desc
  KUSTO
}

resource "azurerm_log_analytics_saved_search" "exceptions" {
  name                       = "ApplicationExceptions"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id
  category                   = "eShopOnWeb"
  display_name               = "Application Exceptions"
  query                      = <<-KUSTO
    AppExceptions
    | summarize count() by ExceptionType, OuterMessage
    | order by count_ desc
  KUSTO
}

# ── Diagnostic Setting for LAW CMK storage blob ───────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "law_cmk_storage_blob" {
  name                       = "diag-stlaw-blob-${var.project}"
  target_resource_id         = "${azurerm_storage_account.law_cmk.id}/blobServices/default"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

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
    category = "AllMetrics"
    enabled  = true
  }
}
