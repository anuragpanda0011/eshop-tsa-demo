# ---------------------------------------------------------------------------
# VPC Network
# ---------------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "Custom VPC for Django reporting application"
}

# ---------------------------------------------------------------------------
# Subnet — Serverless VPC Connector (/28 required by Google)
# ---------------------------------------------------------------------------
resource "google_compute_subnetwork" "connector" {
  project                  = var.project_id
  name                     = "subnet-connector"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_connector_cidr
  private_ip_google_access = true
  description              = "Subnet reserved for Serverless VPC Access Connector"

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ---------------------------------------------------------------------------
# Subnet — Cloud SQL (PSA reference subnet)
# VPC Flow Logs enabled — consistent with connector subnet coverage.
# ---------------------------------------------------------------------------
resource "google_compute_subnetwork" "cloudsql" {
  project                  = var.project_id
  name                     = "subnet-cloudsql"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cloudsql_cidr
  private_ip_google_access = true
  description              = "Subnet for Cloud SQL private service access reference"

  # VPC Flow Logs — enabled to match connector subnet coverage
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ---------------------------------------------------------------------------
# Private Service Access (PSA) — Global IP Range Allocation
# ---------------------------------------------------------------------------
resource "google_compute_global_address" "psa_range" {
  project       = var.project_id
  name          = var.psa_range_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  network       = google_compute_network.vpc.id
  address       = split("/", var.psa_cidr_prefix)[0]
  prefix_length = tonumber(split("/", var.psa_cidr_prefix)[1])
  description   = "Allocated IP range for Cloud SQL private service access (PSA)"
}

# ---------------------------------------------------------------------------
# PSA — Service Networking Connection
# ---------------------------------------------------------------------------
resource "google_service_networking_connection" "psa_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range.name]

  depends_on = [google_compute_global_address.psa_range]
}

# ---------------------------------------------------------------------------
# Serverless VPC Access Connector
# ---------------------------------------------------------------------------
resource "google_vpc_access_connector" "connector" {
  project        = var.project_id
  name           = var.connector_name
  region         = var.region
  network        = google_compute_network.vpc.name
  ip_cidr_range  = var.subnet_connector_cidr
  min_instances  = var.connector_min_instances
  max_instances  = var.connector_max_instances
  machine_type   = var.connector_machine_type

  depends_on = [
    google_compute_subnetwork.connector,
    google_service_networking_connection.psa_connection,
  ]
}

# ---------------------------------------------------------------------------
# Firewall Rules
# ---------------------------------------------------------------------------

# Allow egress from VPC Connector to Cloud SQL on port 5432
resource "google_compute_firewall" "allow_connector_to_cloudsql" {
  project     = var.project_id
  name        = "fw-allow-connector-to-cloudsql"
  network     = google_compute_network.vpc.id
  description = "Allow TCP 5432 egress from VPC connector to Cloud SQL private IP"
  direction   = "EGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  destination_ranges = [var.psa_cidr_prefix]
  target_tags        = ["vpcaccess-connector"]
}

# Allow egress from VPC Connector to Google APIs (restricted VIP only)
resource "google_compute_firewall" "allow_connector_to_google_apis" {
  project     = var.project_id
  name        = "fw-allow-connector-to-google-apis"
  network     = google_compute_network.vpc.id
  description = "Allow egress from VPC connector to Google restricted/private VIPs"
  direction   = "EGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  destination_ranges = [
    "199.36.153.8/30",  # restricted.googleapis.com
    "199.36.153.4/30",  # private.googleapis.com
  ]

  target_tags = ["vpcaccess-connector"]
}

# Deny all other egress (default-deny at low priority)
resource "google_compute_firewall" "deny_all_egress" {
  project     = var.project_id
  name        = "fw-deny-all-egress"
  network     = google_compute_network.vpc.id
  description = "Default deny-all egress; specific allow rules take priority"
  direction   = "EGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

# Allow internal ingress within the VPC CIDR ranges
resource "google_compute_firewall" "allow_internal_ingress" {
  project     = var.project_id
  name        = "fw-allow-internal-ingress"
  network     = google_compute_network.vpc.id
  description = "Allow internal ingress within VPC CIDR ranges"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.subnet_connector_cidr,
    var.subnet_cloudsql_cidr,
    var.psa_cidr_prefix,
  ]
}

# Allow Google health check probes to VPC connector instances ONLY
resource "google_compute_firewall" "allow_health_checks" {
  project     = var.project_id
  name        = "fw-allow-health-checks"
  network     = google_compute_network.vpc.id
  description = "Allow Google health check probe IPs ingress to connector VMs only"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
    "209.85.152.0/22",
    "209.85.204.0/22",
  ]

  target_tags = ["vpcaccess-connector"]
}
