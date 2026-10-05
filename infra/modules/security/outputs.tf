output "cloudrun_sa_email" {
  description = "Email address of the Cloud Run service account."
  value       = google_service_account.cloudrun.email
}

output "cloudrun_sa_name" {
  description = "Resource name of the Cloud Run service account."
  value       = google_service_account.cloudrun.name
}

output "cloudrun_sa_id" {
  description = "Unique ID of the Cloud Run service account."
  value       = google_service_account.cloudrun.unique_id
}

output "cloudbuild_sa_email" {
  description = "Email address of the Cloud Build service account."
  value       = google_service_account.cloudbuild.email
}

output "cloudbuild_sa_name" {
  description = "Resource name of the Cloud Build service account."
  value       = google_service_account.cloudbuild.name
}

output "db_password_secret_id" {
  description = "Resource ID of the db-password secret."
  value       = google_secret_manager_secret.db_password.id
}

output "db_password_secret_name" {
  description = "Secret Manager secret name (projects/<project>/secrets/db-password)."
  value       = google_secret_manager_secret.db_password.name
}
