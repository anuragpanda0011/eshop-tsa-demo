output "cloud_run_url" {
  description = "The HTTPS URL of the deployed Cloud Run service."
  value       = google_cloud_run_v2_service.reporting.uri
}

output "cloud_run_service_name" {
  description = "Name of the Cloud Run service."
  value       = google_cloud_run_v2_service.reporting.name
}

output "cloud_run_service_id" {
  description = "Resource ID of the Cloud Run service."
  value       = google_cloud_run_v2_service.reporting.id
}

output "artifact_registry_repository" {
  description = "Full Artifact Registry repository path."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.reporting.repository_id}"
}

output "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID."
  value       = google_artifact_registry_repository.reporting.repository_id
}
