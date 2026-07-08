# ---------------------------------------------------------------------------
# Monitoring Module — Log Analytics Workspace, Application Insights,
#                     Alert Rules, Diagnostic Settings
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Log Analytics Workspace
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Application Insights (Workspace-based)
# ---------------------------------------------------------------------------
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  retention_in_days   = var.log_retention_days
  sampling_percentage = 100
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Diagnostic Settings — Web App
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "web_app" {
  name                       = "diag-web-${var.name_prefix}"
  target_resource_id         = var.web_app_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }
  enabled_log { category = "AppServiceAppLogs" }
  enabled_log { category = "AppServiceAuditLogs" }
  enabled_log { category = "AppServiceIPSecAuditLogs" }
  enabled_log { category = "AppServicePlatformLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ---------------------------------------------------------------------------
# Diagnostic Settings — API App
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "api_app" {
  name                       = "diag-api-${var.name_prefix}"
  target_resource_id         = var.api_app_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }
  enabled_log { category = "AppServiceAppLogs" }
  enabled_log { category = "AppServiceAuditLogs" }
  enabled_log { category = "AppServiceIPSecAuditLogs" }
  enabled_log { category = "AppServicePlatformLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ---------------------------------------------------------------------------
# Diagnostic Settings — Key Vault
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-kv-${var.name_prefix}"
  target_resource_id         = var.key_vault_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "AuditEvent" }
  enabled_log { category = "AzurePolicyEvaluationDetails" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ---------------------------------------------------------------------------
# Alert Action Group
# ---------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  short_name          = "eshop-ops"
  tags                = var.tags

  email_receiver {
    name                    = "ops-email"
    email_address           = var.alert_email_address
    use_common_alert_schema = true
  }
}

# ---------------------------------------------------------------------------
# Alert: Web App — 5xx Error Rate
# ---------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "web_5xx_errors" {
  name                = "alert-web-5xx-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.web_app_id]
  description         = "P1: Web App 5xx HTTP error rate exceeded threshold for 5 minutes."
  severity            = 0
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ---------------------------------------------------------------------------
# Alert: API — 5xx Error Rate
# ---------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "api_5xx_errors" {
  name                = "alert-api-5xx-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.api_app_id]
  description         = "P1: API 5xx HTTP error rate exceeded threshold for 5 minutes."
  severity            = 0
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ---------------------------------------------------------------------------
# Alert: Web App — High Memory
# ---------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "web_memory" {
  name                = "alert-web-memory-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.web_app_id]
  description         = "P2: Web App memory usage exceeded 80% for 10 minutes."
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT10M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "MemoryWorkingSet"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 838860800 # 800 MB in bytes
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ---------------------------------------------------------------------------
# Alert: API — High Memory
# ---------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "api_memory" {
  name                = "alert-api-memory-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.api_app_id]
  description         = "P2: API memory usage exceeded 80% for 10 minutes."
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT10M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "MemoryWorkingSet"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 838860800 # 800 MB in bytes
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ---------------------------------------------------------------------------
# Alert: Redis — High CPU
# ---------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "redis_cpu" {
  name                = "alert-redis-cpu-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.redis_id]
  description         = "P2: Redis server load exceeded 80% for 5 minutes."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Cache/redis"
    metric_name      = "percentProcessorTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ---------------------------------------------------------------------------
# Alert: Key Vault — High Latency / Saturation
# ---------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "kv_availability" {
  name                = "alert-kv-availability-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.key_vault_id]
  description         = "P2: Key Vault availability dropped below 99% for 5 minutes."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.KeyVault/vaults"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
