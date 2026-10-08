# ===========================================================================
# Monitoring Module
# Provisions: Log Analytics Workspace, Application Insights (workspace-based),
#             Action Groups, Alert Rules, Dashboards
# ===========================================================================

locals {
  prefix = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Log Analytics Workspace
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = -1 # No daily cap in production
  tags                = var.tags
}

resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name
  tags                  = var.tags

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

resource "azurerm_log_analytics_solution" "security_center" {
  solution_name         = "SecurityCenterFree"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name
  tags                  = var.tags

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityCenterFree"
  }
}

# ---------------------------------------------------------------------------
# Application Insights (workspace-based)
# ---------------------------------------------------------------------------
resource "azurerm_application_insights" "main" {
  name                = "ai-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  retention_in_days   = var.log_retention_days
  sampling_percentage = 100
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Action Group (email + optional webhook)
# ---------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-ops-${local.prefix}"
  resource_group_name = var.resource_group_name
  short_name          = "ops-team"
  tags                = var.tags

  email_receiver {
    name                    = "ops-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# ---------------------------------------------------------------------------
# Alert Rules
# ---------------------------------------------------------------------------

data "azurerm_subscription" "current" {}

# High CPU on ACA
resource "azurerm_monitor_metric_alert" "high_cpu" {
  name                = "alert-high-cpu-${local.prefix}"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"]
  description         = "Fires when average CPU usage across the resource group exceeds 80% for 5 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# High Memory
resource "azurerm_monitor_metric_alert" "high_memory" {
  name                = "alert-high-memory-${local.prefix}"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"]
  description         = "Fires when memory exceeds 80% for 5 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "MemoryWorkingSetBytes"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 1610612736 # 1.5 GiB in bytes
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# Application Insights — Failed Requests alert
resource "azurerm_monitor_metric_alert" "failed_requests" {
  name                = "alert-failed-requests-${local.prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Fires when failed requests exceed 10 in a 5-minute window."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# Application Insights — Availability alert
resource "azurerm_monitor_metric_alert" "availability" {
  name                = "alert-availability-${local.prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Fires when availability drops below 99%."
  severity            = 0
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "availabilityResults/availabilityPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# Application Insights — Response Time (p95 > 2s)
resource "azurerm_monitor_metric_alert" "response_time" {
  name                = "alert-response-time-${local.prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Fires when average server response time exceeds 2 seconds."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 2000 # milliseconds
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# Application Insights — Exception rate
resource "azurerm_monitor_metric_alert" "exceptions" {
  name                = "alert-exceptions-${local.prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Fires when exception count exceeds 20 in 5 minutes."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "exceptions/count"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 20
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# ---------------------------------------------------------------------------
# Application Insights Web Test (Availability ping)
#
# SECURITY NOTE: A shared secret token is added as a request header
# (X-Health-Probe-Token). Configure Front Door or the application to require
# this header on /health requests to prevent unauthenticated probing.
# ---------------------------------------------------------------------------
resource "azurerm_application_insights_web_test" "storefront_ping" {
  name                    = "webtest-storefront-${local.prefix}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  application_insights_id = azurerm_application_insights.main.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr", "us-va-ash-azr", "emea-nl-ams-azr", "apac-sg-sin-azr"]
  tags                    = var.tags

  configuration = <<XML
<WebTest Name="StorefrontPing" Enabled="True" Timeout="30" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Items>
    <Request Method="GET" Guid="a0001" Version="1.1" Url="https://${var.storefront_url != "" ? var.storefront_url : "placeholder.example.com"}" ThinkTime="0" Timeout="30" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False">
      <Headers>
        <Header Name="X-Health-Probe-Token" Value="${var.health_probe_token}" />
      </Headers>
    </Request>
  </Items>
</WebTest>
XML
}

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------
resource "azurerm_portal_dashboard" "main" {
  name                = "dashboard-${local.prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = merge(var.tags, { hidden-title = "eShopOnWeb Production" })

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = { x = 0, y = 0, rowSpan = 4, colSpan = 6 }
            metadata = {
              type = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
              inputs = [
                {
                  name = "options"
                  value = {
                    chart = {
                      title   = "ACA CPU Usage"
                      metrics = []
                    }
                  }
                }
              ]
            }
          }
          "1" = {
            position = { x = 6, y = 0, rowSpan = 4, colSpan = 6 }
            metadata = {
              type = "Extension/AppInsightsExtension/PartType/AvailabilityNavButtonPart"
              inputs = [
                {
                  name  = "ComponentId"
                  value = azurerm_application_insights.main.id
                }
              ]
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 24
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  })
}
