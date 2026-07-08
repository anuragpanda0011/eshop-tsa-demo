output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.main.name
}

output "app_insights_id" {
  description = "Resource ID of the Application Insights instance."
  value       = azurerm_application_insights.main.id
}

output "app_insights_instrumentation_key" {
  description = "Application Insights Instrumentation Key."
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Application Insights connection string."
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "action_group_id" {
  description = "Resource ID of the Monitor Action Group."
  value       = azurerm_monitor_action_group.main.id
}
