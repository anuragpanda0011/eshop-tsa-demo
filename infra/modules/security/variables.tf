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

variable "pdf_bucket_name" {
  description = "Name of the PDF reports Cloud Storage bucket (for IAM binding scope)."
  type        = string

  validation {
    condition     = length(var.pdf_bucket_name) > 0
    error_message = "pdf_bucket_name must not be empty."
  }
}

variable "artifact_registry_repo_id" {
  description = "Artifact Registry repository ID (used to scope Cloud Build IAM to the specific repo)."
  type        = string

  validation {
    condition     = length(var.artifact_registry_repo_id) > 0
    error_message = "artifact_registry_repo_id must not be empty."
  }
}

variable "db_instance_name_prefix" {
  description = "Cloud SQL instance name prefix used in IAM condition to scope sql.client role. Must match the db_instance_name root variable."
  type        = string
  default     = "cloudsql-reporting"

  validation {
    condition     = length(var.db_instance_name_prefix) > 0
    error_message = "db_instance_name_prefix must not be empty."
  }
}

variable "kms_key_name" {
  description = "Cloud KMS key resource name for Secret Manager CMEK encryption. The key must be in the 'global' location for Secret Manager auto-replication. Format: projects/<project>/locations/global/keyRings/<ring>/cryptoKeys/<key>. The Secret Manager service agent must have roles/cloudkms.cryptoKeyEncrypterDecrypter on this key."
  type        = string

  validation {
    condition     = length(var.kms_key_name) > 0
    error_message = "kms_key_name must not be empty. Provide a Cloud KMS key for Secret Manager CMEK encryption."
  }
}

variable "labels" {
  description = "Labels to apply to resources."
  type        = map(string)
  default     = {}
}
