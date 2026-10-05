output "log_analytics_workspace_id" {
  value = data.azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  value = data.azurerm_log_analytics_workspace.main.name
}

output "app_insights_id" {
  value = azurerm_application_insights.main.id
}

# FIX: instrumentation_key output REMOVED.
# The instrumentation key is a legacy shared secret granting unauthenticated
# write access to App Insights. With local_authentication_disabled = true,
# key-based ingestion is disabled. Use connection_string only.
# Removing this output prevents accidental exposure via terraform output or
# state access by parties who should not have write access to telemetry.

output "app_insights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}

output "app_insights_secret_name" {
  value = "appinsights-connection-string"
}

output "action_group_id" {
  value = azurerm_monitor_action_group.main.id
}

output "workbook_id" {
  value = azurerm_application_insights_workbook.main.id
}
