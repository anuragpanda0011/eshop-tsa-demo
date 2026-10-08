output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_key" {
  description = "Primary shared key of the Log Analytics workspace (sensitive)."
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "app_insights_id" {
  description = "Resource ID of the Application Insights component."
  value       = azurerm_application_insights.main.id
}

output "app_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights (sensitive)."
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Connection string for Application Insights (sensitive)."
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "app_insights_app_id" {
  description = "Application ID of the Application Insights component."
  value       = azurerm_application_insights.main.app_id
}

output "action_group_id" {
  description = "Resource ID of the ops action group."
  value       = azurerm_monitor_action_group.ops.id
}
