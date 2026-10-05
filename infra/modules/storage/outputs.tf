output "bucket_name" {
  description = "Name of the PDF reports Cloud Storage bucket."
  value       = google_storage_bucket.pdf_reports.name
}

output "bucket_url" {
  description = "gs:// URL of the PDF reports bucket."
  value       = "gs://${google_storage_bucket.pdf_reports.name}"
}

output "bucket_self_link" {
  description = "Self link of the PDF reports bucket."
  value       = google_storage_bucket.pdf_reports.self_link
}

output "cloudbuild_cache_bucket_name" {
  description = "Name of the Cloud Build cache bucket."
  value       = google_storage_bucket.cloudbuild_cache.name
}

output "access_logs_bucket_name" {
  description = "Name of the GCS access-log bucket."
  value       = google_storage_bucket.access_logs.name
}
