###############################################################################
# Log Analytics Workspace
###############################################################################
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags

  daily_quota_gb = 5
}

###############################################################################
# Application Insights
###############################################################################
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  retention_in_days   = 90
  tags                = var.tags

  disable_ip_masking = false
}

###############################################################################
# Action Group (email alerts)
###############################################################################
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "eshop-ops"
  tags                = var.tags

  email_receiver {
    name                    = "platform-ops"
    email_address           = var.alert_action_group_email
    use_common_alert_schema = true
  }
}

###############################################################################
# Smart Detection (Anomaly detection built into App Insights)
###############################################################################
resource "azurerm_application_insights_smart_detection_rule" "slow_page_load" {
  name                    = "Slow page load time"
  application_insights_id = azurerm_application_insights.main.id
  enabled                 = true
}

resource "azurerm_application_insights_smart_detection_rule" "slow_server_response" {
  name                    = "Slow server response time"
  application_insights_id = azurerm_application_insights.main.id
  enabled                 = true
}

resource "azurerm_application_insights_smart_detection_rule" "long_dependency_duration" {
  name                    = "Long dependency duration"
  application_insights_id = azurerm_application_insights.main.id
  enabled                 = true
}

resource "azurerm_application_insights_smart_detection_rule" "degradation_server_response" {
  name                    = "Degradation in server response time"
  application_insights_id = azurerm_application_insights.main.id
  enabled                 = true
}

resource "azurerm_application_insights_smart_detection_rule" "degradation_dependency_duration" {
  name                    = "Degradation in dependency duration"
  application_insights_id = azurerm_application_insights.main.id
  enabled                 = true
}

###############################################################################
# Azure Monitor Alerts
# These resources depend on compute outputs — the monitoring module must be
# called with web_app_id, api_app_id, web_service_plan_id from main.tf.
###############################################################################

# High CPU alert on web service plan
resource "azurerm_monitor_metric_alert" "web_cpu_critical" {
  count               = var.web_service_plan_id != "" ? 1 : 0
  name                = "alert-web-cpu-critical-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.web_service_plan_id]
  description         = "Web App Service Plan CPU > 90% for 15 minutes"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT15M"
  auto_mitigate       = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/serverfarms"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# HTTP 5xx errors — Web
resource "azurerm_monitor_metric_alert" "web_http5xx" {
  count               = var.web_app_id != "" ? 1 : 0
  name                = "alert-web-http5xx-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.web_app_id]
  description         = "Web App HTTP 5xx errors > 10 in 5 minutes"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true
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

# HTTP 5xx errors — API
resource "azurerm_monitor_metric_alert" "api_http5xx" {
  count               = var.api_app_id != "" ? 1 : 0
  name                = "alert-api-http5xx-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.api_app_id]
  description         = "API App HTTP 5xx errors > 10 in 5 minutes"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true
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

# App Insights failed requests (dynamic threshold)
resource "azurerm_monitor_metric_alert" "app_insights_failed_requests" {
  name                = "alert-appi-failed-requests-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Application Insights failed requests rate > 5%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  auto_mitigate       = true
  tags                = var.tags

  dynamic_criteria {
    metric_namespace         = "microsoft.insights/components"
    metric_name              = "requests/failed"
    aggregation              = "Count"
    operator                 = "GreaterThan"
    alert_sensitivity        = "Medium"
    evaluation_total_count   = 4
    evaluation_failure_count = 4
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

###############################################################################
# Application Insights Web Tests (availability)
###############################################################################
resource "azurerm_application_insights_web_test" "web_health" {
  count                   = var.web_app_hostname != "" ? 1 : 0
  name                    = "webtest-web-health-${var.environment}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  application_insights_id = azurerm_application_insights.main.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["us-fl-mia-edge", "us-tx-sn1-azr", "us-il-ch1-azr", "us-va-ash-azr", "us-ca-sjc-azr"]
  tags                    = var.tags

  configuration = <<XML
<WebTest Name="web-health-check" Enabled="True" Timeout="30" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" PreAuthenticate="True">
  <Items>
    <Request Method="GET" Guid="1" Version="1.1" Url="https://${var.web_app_hostname}/health" ThinkTime="0" Timeout="30" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" />
  </Items>
</WebTest>
XML
}

resource "azurerm_application_insights_web_test" "api_health" {
  count                   = var.api_app_hostname != "" ? 1 : 0
  name                    = "webtest-api-health-${var.environment}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  application_insights_id = azurerm_application_insights.main.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["us-fl-mia-edge", "us-tx-sn1-azr", "us-il-ch1-azr", "us-va-ash-azr", "us-ca-sjc-azr"]
  tags                    = var.tags

  configuration = <<XML
<WebTest Name="api-health-check" Enabled="True" Timeout="30" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" PreAuthenticate="True">
  <Items>
    <Request Method="GET" Guid="2" Version="1.1" Url="https://${var.api_app_hostname}/health" ThinkTime="0" Timeout="30" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" />
  </Items>
</WebTest>
XML
}

###############################################################################
# Workbook (basic App Performance workbook)
###############################################################################
resource "azurerm_application_insights_workbook" "main" {
  name                = "workbook-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  display_name        = "eShop Application Performance"
  tags                = var.tags

  data_json = jsonencode({
    version  = "Notebook/1.0"
    items    = [
      {
        type = 1
        content = {
          json = "# eShopOnWeb Application Performance\nThis workbook shows key performance indicators for the eShopOnWeb application."
        }
      }
    ]
    isLocked = false
    fallbackResourceIds = [azurerm_application_insights.main.id]
  })
}
