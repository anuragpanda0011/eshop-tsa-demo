# ---------------------------------------------------------------------------
# Project & Region
# ---------------------------------------------------------------------------
variable "project_id" {
  description = "GCP project ID where all resources will be created."
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "GCP region for all regional resources."
  type        = string
  default     = "us-central1"
}

variable "zone_primary" {
  description = "Primary GCP zone (used for Cloud SQL primary instance)."
  type        = string
  default     = "us-central1-b"
}

variable "zone_secondary" {
  description = "Secondary GCP zone (used for Cloud SQL HA standby)."
  type        = string
  default     = "us-central1-c"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vpc_name" {
  description = "Name of the custom VPC network."
  type        = string
  default     = "vpc-reporting"
}

variable "subnet_connector_cidr" {
  description = "CIDR for the Serverless VPC Access Connector subnet (/28 required)."
  type        = string
  default     = "10.8.0.0/28"
}

variable "subnet_cloudsql_cidr" {
  description = "CIDR for the Cloud SQL private subnet."
  type        = string
  default     = "10.8.1.0/29"
}

variable "psa_range_name" {
  description = "Name for the Private Service Access allocated IP range."
  type        = string
  default     = "psa-range-reporting"
}

variable "psa_cidr_prefix" {
  description = "CIDR prefix for the PSA allocated range (Google-managed, /16 recommended)."
  type        = string
  default     = "10.100.0.0/16"
}

variable "connector_name" {
  description = "Name of the Serverless VPC Access Connector."
  type        = string
  default     = "connector-reporting"
}

variable "connector_min_instances" {
  description = "Minimum number of VPC connector instances."
  type        = number
  default     = 2
}

variable "connector_max_instances" {
  description = "Maximum number of VPC connector instances."
  type        = number
  default     = 3
}

variable "connector_machine_type" {
  description = "Machine type for VPC connector instances."
  type        = string
  default     = "e2-micro"
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
variable "db_instance_name" {
  description = "Name of the Cloud SQL instance."
  type        = string
  default     = "cloudsql-reporting"
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-g1-small"
}

variable "db_postgres_version" {
  description = "PostgreSQL version for Cloud SQL."
  type        = string
  default     = "POSTGRES_15"
}

variable "db_name" {
  description = "PostgreSQL database name to create."
  type        = string
  default     = "reporting"
}

variable "db_user" {
  description = "PostgreSQL application user name."
  type        = string
  default     = "reporting_app"
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 7
}

variable "db_pitr_days" {
  description = "Number of days for Point-in-Time Recovery transaction log retention."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on the Cloud SQL instance."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Compute / Cloud Run
# ---------------------------------------------------------------------------
variable "cloudrun_service_name" {
  description = "Name of the Cloud Run service."
  type        = string
  default     = "cloudrun-reporting"
}

variable "cloudrun_min_instances" {
  description = "Minimum Cloud Run instances (set to 1 to avoid cold starts)."
  type        = number
  default     = 1
}

variable "cloudrun_max_instances" {
  description = "Maximum Cloud Run instances."
  type        = number
  default     = 5
}

variable "cloudrun_concurrency" {
  description = "Maximum concurrent requests per Cloud Run instance."
  type        = number
  default     = 80
}

variable "cloudrun_cpu" {
  description = "CPU allocation for each Cloud Run instance."
  type        = string
  default     = "1000m"
}

variable "cloudrun_memory" {
  description = "Memory allocation for each Cloud Run instance."
  type        = string
  default     = "1Gi"
}

variable "cloudrun_timeout_seconds" {
  description = "Request timeout for Cloud Run service in seconds."
  type        = number
  default     = 300
}

variable "cloudrun_allow_unauthenticated" {
  description = "Allow unauthenticated public access to Cloud Run service via HTTPS LB only. When true, a Cloud Armor policy (cloud_armor_policy_name) and HTTPS LB must already be deployed, and waf_policy_acknowledged must be true."
  type        = bool
  # SECURITY: default false — explicit opt-in required.
  default     = false
}

variable "waf_policy_acknowledged" {
  description = "Set to true ONLY after a Cloud Armor security policy (named by cloud_armor_policy_name) and HTTPS Load Balancer are deployed and verified in this project. A data source lookup validates the policy exists at plan time."
  type        = bool
  # SECURITY: default false — explicit opt-in required.
  default     = false
}

variable "cloud_armor_policy_name" {
  description = "Name of an existing Cloud Armor security policy. Required when waf_policy_acknowledged=true. Must name a real, deployed policy in the same project — validated by a data source lookup at plan time."
  type        = string
  default     = ""
}

variable "django_settings_module" {
  description = "Django settings module path."
  type        = string
  default     = "config.settings.production"
}

# ---------------------------------------------------------------------------
# Artifact Registry
# ---------------------------------------------------------------------------
variable "artifact_registry_repo_id" {
  description = "Artifact Registry repository ID."
  type        = string
  default     = "reporting"

  validation {
    condition     = length(var.artifact_registry_repo_id) > 0
    error_message = "artifact_registry_repo_id must not be empty."
  }
}

variable "artifact_registry_keep_count" {
  description = "Number of most-recent tagged Docker images to retain."
  type        = number
  default     = 10
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------
variable "pdf_bucket_name_prefix" {
  description = "Prefix for the PDF reports Cloud Storage bucket name (project ID is appended)."
  type        = string
  default     = "pdf-reports"
}

variable "pdf_bucket_nearline_days" {
  description = "Days after which objects transition to NEARLINE storage class."
  type        = number
  default     = 90
}

variable "pdf_bucket_coldline_days" {
  description = "Days after which objects transition to COLDLINE storage class."
  type        = number
  default     = 365
}

variable "pdf_bucket_delete_days" {
  description = "Days after which objects are deleted (7 years = 2555 days)."
  type        = number
  default     = 2555
}

variable "cors_allowed_origins" {
  description = "List of allowed CORS origins for the PDF reports bucket. Wildcard '*' is explicitly rejected."
  type        = list(string)

  validation {
    condition     = !contains(var.cors_allowed_origins, "*")
    error_message = "cors_allowed_origins must not contain '*'. Specify exact origins."
  }

  validation {
    condition     = length(var.cors_allowed_origins) > 0
    error_message = "cors_allowed_origins must contain at least one origin."
  }
}

# ---------------------------------------------------------------------------
# CMEK — Customer-Managed Encryption Keys
# ---------------------------------------------------------------------------
variable "kms_key_name" {
  description = "Cloud KMS key for GCS bucket CMEK encryption. Must be in the same region as the buckets. The GCS service account must have roles/cloudkms.cryptoKeyEncrypterDecrypter on this key. Format: projects/<p>/locations/<r>/keyRings/<kr>/cryptoKeys/<k>"
  type        = string

  validation {
    condition     = length(var.kms_key_name) > 0
    error_message = "kms_key_name must not be empty."
  }
}

variable "log_bucket_kms_key_name" {
  description = "Cloud KMS key for Cloud Logging bucket CMEK encryption. Must be in the same region as the log buckets. The Cloud Logging service account must have roles/cloudkms.cryptoKeyEncrypterDecrypter on this key."
  type        = string

  validation {
    condition     = length(var.log_bucket_kms_key_name) > 0
    error_message = "log_bucket_kms_key_name must not be empty."
  }
}

variable "security_kms_key_name" {
  description = "Cloud KMS key for Secret Manager CMEK encryption. Must be in the 'global' location. The Secret Manager service account must have roles/cloudkms.cryptoKeyEncrypterDecrypter on this key."
  type        = string

  validation {
    condition     = length(var.security_kms_key_name) > 0
    error_message = "security_kms_key_name must not be empty."
  }
}

# ---------------------------------------------------------------------------
# CI/CD
# ---------------------------------------------------------------------------
variable "github_owner" {
  description = "GitHub repository owner (user or organisation)."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name (without owner prefix)."
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "Git branch to trigger Cloud Build on."
  type        = string
  default     = "main"
}

variable "create_cloud_dns" {
  description = "Whether to create a Cloud DNS managed zone for custom domain."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Cloud DNS managed zone name (only used if create_cloud_dns = true)."
  type        = string
  default     = "reporting-zone"
}

variable "dns_domain" {
  description = "DNS domain for the managed zone, e.g. reports.example.com. (trailing dot required)"
  type        = string
  default     = "reports.example.com."
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------
variable "alert_email" {
  description = "Email address to receive monitoring alerts."
  type        = string

  validation {
    condition     = length(var.alert_email) > 0 && can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

variable "alert_high_error_rate_threshold" {
  description = "5xx error rate threshold (fraction, e.g. 0.05 = 5%) to trigger alert."
  type        = number
  default     = 0.05
}

variable "alert_latency_p95_threshold_ms" {
  description = "p95 latency threshold in milliseconds to trigger alert."
  type        = number
  default     = 10000
}

variable "alert_sql_disk_threshold" {
  description = "Cloud SQL disk utilisation fraction threshold (e.g. 0.80 = 80%)."
  type        = number
  default     = 0.80
}

variable "alert_sql_cpu_threshold" {
  description = "Cloud SQL CPU utilisation fraction threshold (e.g. 0.90 = 90%)."
  type        = number
  default     = 0.90
}

variable "labels" {
  description = "Common labels to apply to all resources."
  type        = map(string)
  default = {
    environment = "production"
    application = "django-reporting"
    managed_by  = "terraform"
  }
}
