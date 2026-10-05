# ---------------------------------------------------------------------------
# Enable required GCP APIs
# ---------------------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com",
    "dns.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    # Required for Artifact Registry vulnerability scanning
    "containeranalysis.googleapis.com",
    "cloudkms.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Network Module
# ---------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  project_id              = var.project_id
  region                  = var.region
  vpc_name                = var.vpc_name
  subnet_connector_cidr   = var.subnet_connector_cidr
  subnet_cloudsql_cidr    = var.subnet_cloudsql_cidr
  psa_range_name          = var.psa_range_name
  psa_cidr_prefix         = var.psa_cidr_prefix
  connector_name          = var.connector_name
  connector_min_instances = var.connector_min_instances
  connector_max_instances = var.connector_max_instances
  connector_machine_type  = var.connector_machine_type
  labels                  = var.labels

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Security / Identity Module
# ---------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  project_id                 = var.project_id
  region                     = var.region
  pdf_bucket_name            = module.storage.bucket_name
  artifact_registry_repo_id  = var.artifact_registry_repo_id
  db_instance_name_prefix    = var.db_instance_name
  kms_key_name               = var.security_kms_key_name
  labels                     = var.labels

  depends_on = [
    google_project_service.apis,
    module.storage,
  ]
}

# ---------------------------------------------------------------------------
# Database Module
# ---------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  project_id               = var.project_id
  region                   = var.region
  zone_primary             = var.zone_primary
  zone_secondary           = var.zone_secondary
  vpc_id                   = module.network.vpc_id
  db_instance_name         = var.db_instance_name
  db_tier                  = var.db_tier
  db_postgres_version      = var.db_postgres_version
  db_name                  = var.db_name
  db_user                  = var.db_user
  db_backup_retention_days = var.db_backup_retention_days
  db_pitr_days             = var.db_pitr_days
  db_deletion_protection   = var.db_deletion_protection
  labels                   = var.labels

  depends_on = [
    google_project_service.apis,
    module.network,
  ]
}

# ---------------------------------------------------------------------------
# Storage Module
# ---------------------------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  project_id               = var.project_id
  region                   = var.region
  pdf_bucket_name_prefix   = var.pdf_bucket_name_prefix
  pdf_bucket_nearline_days = var.pdf_bucket_nearline_days
  pdf_bucket_coldline_days = var.pdf_bucket_coldline_days
  pdf_bucket_delete_days   = var.pdf_bucket_delete_days
  cors_allowed_origins     = var.cors_allowed_origins
  kms_key_name             = var.kms_key_name
  labels                   = var.labels

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Compute Module (Cloud Run + Artifact Registry)
# ---------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  project_id                     = var.project_id
  region                         = var.region
  cloudrun_service_name          = var.cloudrun_service_name
  cloudrun_min_instances         = var.cloudrun_min_instances
  cloudrun_max_instances         = var.cloudrun_max_instances
  cloudrun_concurrency           = var.cloudrun_concurrency
  cloudrun_cpu                   = var.cloudrun_cpu
  cloudrun_memory                = var.cloudrun_memory
  cloudrun_timeout_seconds       = var.cloudrun_timeout_seconds
  cloudrun_allow_unauthenticated = var.cloudrun_allow_unauthenticated
  waf_policy_acknowledged        = var.waf_policy_acknowledged
  cloud_armor_policy_name        = var.cloud_armor_policy_name
  cloudrun_service_account_email = module.security.cloudrun_sa_email
  vpc_connector_id               = module.network.vpc_connector_id
  db_host                        = module.database.private_ip
  db_name                        = var.db_name
  db_user                        = var.db_user
  db_password_secret_id          = module.security.db_password_secret_id
  pdf_bucket_name                = module.storage.bucket_name
  django_settings_module         = var.django_settings_module
  artifact_registry_repo_id      = var.artifact_registry_repo_id
  artifact_registry_keep_count   = var.artifact_registry_keep_count
  labels                         = var.labels

  depends_on = [
    google_project_service.apis,
    module.network,
    module.security,
    module.database,
    module.storage,
  ]
}

# ---------------------------------------------------------------------------
# CI/CD Module (Cloud Build + Cloud DNS)
# ---------------------------------------------------------------------------
module "ci_cd" {
  source = "./modules/ci_cd"

  project_id                     = var.project_id
  region                         = var.region
  github_owner                   = var.github_owner
  github_repo                    = var.github_repo
  github_branch                  = var.github_branch
  artifact_registry_repo_id      = var.artifact_registry_repo_id
  cloudrun_service_name          = var.cloudrun_service_name
  db_connection_name             = module.database.connection_name
  db_name                        = var.db_name
  db_user                        = var.db_user
  db_password_secret_id          = module.security.db_password_secret_id
  cloudbuild_sa_email            = module.security.cloudbuild_sa_email
  create_cloud_dns               = var.create_cloud_dns
  dns_zone_name                  = var.dns_zone_name
  dns_domain                     = var.dns_domain
  cloud_run_url                  = module.compute.cloud_run_url
  labels                         = var.labels

  depends_on = [
    google_project_service.apis,
    module.compute,
    module.security,
    module.database,
  ]
}

# ---------------------------------------------------------------------------
# Monitoring Module
# ---------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  project_id                      = var.project_id
  region                          = var.region
  cloudrun_service_name           = var.cloudrun_service_name
  db_instance_name                = module.database.instance_name
  pdf_bucket_name                 = module.storage.bucket_name
  alert_email                     = var.alert_email
  alert_high_error_rate_threshold = var.alert_high_error_rate_threshold
  alert_latency_p95_threshold_ms  = var.alert_latency_p95_threshold_ms
  alert_sql_disk_threshold        = var.alert_sql_disk_threshold
  alert_sql_cpu_threshold         = var.alert_sql_cpu_threshold
  cloudrun_max_instances          = var.cloudrun_max_instances
  log_bucket_kms_key_name         = var.log_bucket_kms_key_name
  labels                          = var.labels

  depends_on = [
    google_project_service.apis,
    module.compute,
    module.database,
    module.storage,
  ]
}
