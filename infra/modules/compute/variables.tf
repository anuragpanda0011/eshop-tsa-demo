variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "cloudrun_service_name" {
  description = "Name of the Cloud Run service."
  type        = string
}

variable "cloudrun_min_instances" {
  description = "Minimum Cloud Run instances."
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
  description = "CPU allocation for each Cloud Run instance (e.g. '1000m')."
  type        = string
  default     = "1000m"
}

variable "cloudrun_memory" {
  description = "Memory allocation for each Cloud Run instance (e.g. '1Gi')."
  type        = string
  default     = "1Gi"
}

variable "cloudrun_timeout_seconds" {
  description = "Request timeout for Cloud Run service in seconds."
  type        = number
  default     = 300
}

variable "cloudrun_allow_unauthenticated" {
  description = "Whether to allow unauthenticated public invocations via the HTTPS LB. Requires waf_policy_acknowledged=true and a real Cloud Armor security policy referenced by cloud_armor_policy_name."
  type        = bool
  # SECURITY: default to false — explicit opt-in required.
  default     = false
}

variable "waf_policy_acknowledged" {
  description = "Set to true ONLY after a Cloud Armor WAF policy (named by cloud_armor_policy_name) and HTTPS Load Balancer are deployed and verified. A data source lookup validates the policy exists at plan time."
  type        = bool
  # SECURITY: default to false — explicit opt-in required.
  default     = false
}

variable "cloud_armor_policy_name" {
  description = "Name of an existing Cloud Armor security policy in the same project. Required when waf_policy_acknowledged=true. Used to validate WAF deployment via a data source lookup."
  type        = string
  default     = ""
}

variable "cloudrun_service_account_email" {
  description = "Email of the service account to attach to Cloud Run."
  type        = string
}

variable "vpc_connector_id" {
  description = "Resource ID of the Serverless VPC Access Connector."
  type        = string
}

variable "db_host" {
  description = "Private IP address of the Cloud SQL instance."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
}

variable "db_user" {
  description = "PostgreSQL user name."
  type        = string
}

variable "db_password_secret_id" {
  description = "Resource ID of the Secret Manager secret holding the DB password."
  type        = string
}

variable "pdf_bucket_name" {
  description = "Name of the PDF reports Cloud Storage bucket."
  type        = string
}

variable "django_settings_module" {
  description = "Django settings module path."
  type        = string
  default     = "config.settings.production"
}

variable "artifact_registry_repo_id" {
  description = "Artifact Registry repository ID."
  type        = string
  default     = "reporting"
}

variable "artifact_registry_keep_count" {
  description = "Number of most-recent tagged Docker images to retain."
  type        = number
  default     = 10
}

variable "labels" {
  description = "Labels to apply to resources."
  type        = map(string)
  default     = {}
}
