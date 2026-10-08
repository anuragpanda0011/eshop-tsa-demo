# ── Monitoring Bootstrap Module ────────────────────────────────────────────────
# This minimal module creates only the Log Analytics Workspace.
# It is instantiated before the security module to break the circular dependency:
#   security module needs LAW ID (for KV diagnostic settings)
#   full monitoring module needs KV ID (for CMK on LAW storage)
#
# The full monitoring module (modules/monitoring) references this workspace via
# a data source and attaches CMK linked storage, App Insights, alerts, workbooks.
# There is exactly ONE Log Analytics Workspace instance — created here.

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags

  daily_quota_gb = 10

  # FIX: Prevent accidental destruction of the Log Analytics Workspace.
  # Destroying the workspace would lose all log history and break CMK links,
  # diagnostic settings, and Application Insights associations.
  lifecycle {
    prevent_destroy = true
  }
}
