output "instance_name" {
  description = "Name of the Cloud SQL instance."
  value       = google_sql_database_instance.main.name
}

output "instance_self_link" {
  description = "Self link of the Cloud SQL instance."
  value       = google_sql_database_instance.main.self_link
}

output "connection_name" {
  description = "Cloud SQL connection name (project:region:instance)."
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip" {
  description = "Private IP address assigned to the Cloud SQL instance."
  value       = google_sql_database_instance.main.private_ip_address
  sensitive   = true
}

output "database_name" {
  description = "Name of the PostgreSQL database."
  value       = google_sql_database.reporting.name
}

output "db_user_name" {
  description = "Name of the PostgreSQL application user."
  value       = google_sql_user.reporting_app.name
}
