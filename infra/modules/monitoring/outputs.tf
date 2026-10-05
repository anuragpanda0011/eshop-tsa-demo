output "notification_channel_id" {
  description = "Resource ID of the email notification channel."
  value       = google_monitoring_notification_channel.email.name
}

output "dashboard_name" {
  description = "Resource name of the monitoring dashboard."
  value       = google_monitoring_dashboard.reporting_overview.id
}

output "alert_policy_error_rate_id" {
  description = "Resource name of the high error rate alert policy."
  value       = google_monitoring_alert_policy.cloudrun_high_error_rate.name
}

output "alert_policy_latency_id" {
  description = "Resource name of the high latency alert policy."
  value       = google_monitoring_alert_policy.cloudrun_high_latency.name
}

output "alert_policy_sql_disk_id" {
  description = "Resource name of the Cloud SQL disk alert policy."
  value       = google_monitoring_alert_policy.cloudsql_disk_high.name
}

output "alert_policy_sql_cpu_id" {
  description = "Resource name of the Cloud SQL CPU alert policy."
  value       = google_monitoring_alert_policy.cloudsql_cpu_high.name
}

output "alert_policy_max_instances_id" {
  description = "Resource name of the Cloud Run max instances alert policy."
  value       = google_monitoring_alert_policy.cloudrun_at_max_instances.name
}

output "alert_policy_django_errors_id" {
  description = "Resource name of the Django error spike alert policy."
  value       = google_monitoring_alert_policy.django_error_spike.name
}

output "cloudrun_log_bucket_id" {
  description = "ID of the Cloud Logging bucket for Cloud Run logs."
  value       = google_logging_project_bucket_config.cloudrun_logs.id
}

output "cloudsql_log_bucket_id" {
  description = "ID of the Cloud Logging bucket for Cloud SQL logs."
  value       = google_logging_project_bucket_config.cloudsql_logs.id
}
