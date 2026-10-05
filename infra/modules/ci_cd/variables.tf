variable "project_id" {
  description = "GCP project ID."
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "Branch to trigger Cloud Build on."
  type        = string
  default     = "main"
}

variable "artifact_registry_repo_id" {
  description = "Artifact Registry repository ID."
  type        = string

  validation {
    condition     = length(var.artifact_registry_repo_id) > 0
    error_message = "artifact_registry_repo_id must not be empty."
  }
}

variable "cloudrun_service_name" {
  description = "Cloud Run service name to deploy to."
  type        = string

  validation {
    condition     = length(var.cloudrun_service_name) > 0
    error_message = "cloudrun_service_name must not be empty."
  }
}

variable "db_connection_name" {
  description = "Cloud SQL connection name (project:region:instance) used by the Auth Proxy."
  type        = string

  validation {
    condition     = length(var.db_connection_name) > 0
    error_message = "db_connection_name must not be empty."
  }
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
  description = "Secret Manager secret resource ID for the DB password."
  type        = string

  validation {
    condition     = length(var.db_password_secret_id) > 0
    error_message = "db_password_secret_id must not be empty."
  }
}

variable "cloudbuild_sa_email" {
  description = "Cloud Build service account email."
  type        = string

  validation {
    condition     = length(var.cloudbuild_sa_email) > 0 && can(regex("@.*\\.iam\\.gserviceaccount\\.com$", var.cloudbuild_sa_email))
    error_message = "cloudbuild_sa_email must be a valid service account email."
  }
}

variable "create_cloud_dns" {
  description = "Whether to create a Cloud DNS managed zone."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Cloud DNS managed zone name."
  type        = string
  default     = "reporting-zone"
}

variable "dns_domain" {
  description = "DNS domain for the managed zone (trailing dot required)."
  type        = string
  default     = "reports.example.com."
}

variable "cloud_run_url" {
  description = "Cloud Run service URL."
  type        = string
  default     = ""
}

variable "labels" {
  description = "Labels to apply to resources."
  type        = map(string)
  default     = {}
}
