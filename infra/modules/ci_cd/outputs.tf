output "cloud_build_trigger_id" {
  description = "Cloud Build trigger resource ID (empty if GitHub details not provided)."
  value       = length(google_cloudbuild_trigger.github_push) > 0 ? google_cloudbuild_trigger.github_push[0].id : ""
}

output "cloud_build_trigger_name" {
  description = "Cloud Build trigger name."
  value       = length(google_cloudbuild_trigger.github_push) > 0 ? google_cloudbuild_trigger.github_push[0].name : ""
}

output "dns_zone_name" {
  description = "Cloud DNS managed zone name (empty if not created)."
  value       = length(google_dns_managed_zone.reporting) > 0 ? google_dns_managed_zone.reporting[0].name : ""
}

output "dns_name_servers" {
  description = "Name servers for the Cloud DNS zone (empty if not created)."
  value       = length(google_dns_managed_zone.reporting) > 0 ? google_dns_managed_zone.reporting[0].name_servers : []
}

output "dns_domain" {
  description = "DNS domain of the managed zone."
  value       = var.create_cloud_dns ? var.dns_domain : ""
}
