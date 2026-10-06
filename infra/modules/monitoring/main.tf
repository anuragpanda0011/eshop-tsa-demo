# ---------------------------------------------------------------------------
# Log Analytics Workspace
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags

  daily_quota_gb = 5
}

# ---------------------------------------------------------------------------
# Log Analytics Cluster + CMK (optional, controlled by enable_law_cmk)
# Cost: ~$400/month for the dedicated cluster.
# Enable for regulated workloads handling PII (PCI-DSS, HIPAA, ISO 27001).
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_cluster" "main" {
  count               = var.enable_law_cmk ? 1 : 0
  name                = "lac-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size_gb             = 500
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_log_analytics_cluster_customer_managed_key" "main" {
  count                   = var.enable_law_cmk ? 1 : 0
  log_analytics_cluster_id = azurerm_log_analytics_cluster.main[0].id
  key_vault_key_id        = azurerm_key_vault_key.law_cmk[0].id
}

resource "azurerm_key_vault_key" "law_cmk" {
  count        = var.enable_law_cmk ? 1 : 0
  name         = "key-law-cmk-${var.project}-${var.environment}"
  key_vault_id = var.key_vault_id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  tags         = var.tags
}

resource "azurerm_log_analytics_linked_service" "cluster" {
  count               = var.enable_law_cmk ? 1 : 0
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  read_access_id      = azurerm_log_analytics_cluster.main[0].id
}

# ---------------------------------------------------------------------------
# Application Insights (workspace-based)
# ---------------------------------------------------------------------------
resource "azurerm_application_insights" "main" {
  name                = "ai-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  retention_in_days   = var.log_retention_days
  tags                = var.tags

  daily_data_cap_in_gb = 5
  sampling_percentage  = 100
}

# ---------------------------------------------------------------------------
# Action Group — Ops Email Notifications
# ---------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-ops-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "OpsTeam"
  tags                = var.tags

  email_receiver {
    name                    = "ops-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# ---------------------------------------------------------------------------
# Alert — High exception rate
# ---------------------------------------------------------------------------
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "high_exception_rate" {
  name                = "alert-high-exception-rate-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  scopes               = [azurerm_application_insights.main.id]
  severity             = 2
  description          = "Fires when exception rate exceeds 50 in the last 15 minutes."

  criteria {
    query                   = <<-QUERY
      exceptions
      | where timestamp > ago(15m)
      | summarize ExceptionCount = count() by bin(timestamp, 5m)
      | where ExceptionCount > 50
    QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 3
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.ops.id]
  }
}

# ---------------------------------------------------------------------------
# Alert — High response time
# ---------------------------------------------------------------------------
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "high_response_time" {
  name                = "alert-high-response-time-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  scopes               = [azurerm_application_insights.main.id]
  severity             = 2
  description          = "Fires when average response time exceeds 2 seconds."

  criteria {
    query                   = <<-QUERY
      requests
      | where timestamp > ago(15m)
      | summarize AvgDuration = avg(duration) by bin(timestamp, 5m)
      | where AvgDuration > 2000
    QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 3
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.ops.id]
  }
}

# ---------------------------------------------------------------------------
# Alert — High failed requests
# ---------------------------------------------------------------------------
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "high_failed_requests" {
  name                = "alert-high-failed-requests-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  scopes               = [azurerm_application_insights.main.id]
  severity             = 1
  description          = "Fires when failed request count exceeds 20 in 15 minutes."

  criteria {
    query                   = <<-QUERY
      requests
      | where timestamp > ago(15m)
      | where success == false
      | summarize FailedCount = count() by bin(timestamp, 5m)
      | where FailedCount > 20
    QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 3
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.ops.id]
  }
}

# ---------------------------------------------------------------------------
# Azure Monitor Dashboard
# ---------------------------------------------------------------------------
resource "azurerm_dashboard" "main" {
  name                = "dash-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = merge(var.tags, { "hidden-title" = "eShopOnWeb Operations Dashboard" })

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = { x = 0, y = 0, colSpan = 6, rowSpan = 4 }
            metadata = {
              type = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
              inputs = [
                {
                  name  = "resourceGroup"
                  value = var.resource_group_name
                }
              ]
            }
          }
          "1" = {
            position = { x = 6, y = 0, colSpan = 6, rowSpan = 4 }
            metadata = {
              type   = "Extension/AppInsightsExtension/PartType/AppMapGalPt"
              inputs = []
            }
          }
        }
      }
    }
    metadata = {
      model = {}
    }
  })
}
