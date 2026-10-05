output "vpc_id" {
  description = "The self_link / ID of the VPC network."
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "The self_link of the VPC network."
  value       = google_compute_network.vpc.self_link
}

output "subnet_connector_id" {
  description = "The self_link of the connector subnet."
  value       = google_compute_subnetwork.connector.id
}

output "subnet_connector_name" {
  description = "The name of the connector subnet."
  value       = google_compute_subnetwork.connector.name
}

output "subnet_cloudsql_id" {
  description = "The self_link of the Cloud SQL subnet."
  value       = google_compute_subnetwork.cloudsql.id
}

output "psa_range_name" {
  description = "Name of the PSA global address range."
  value       = google_compute_global_address.psa_range.name
}

output "vpc_connector_id" {
  description = "The fully-qualified resource ID of the Serverless VPC Connector."
  value       = google_vpc_access_connector.connector.id
}

output "vpc_connector_name" {
  description = "The name of the Serverless VPC Connector."
  value       = google_vpc_access_connector.connector.name
}
