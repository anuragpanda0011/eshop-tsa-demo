variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region (used for regional log bucket placement)."
  type        = string
}

variable "cloudrun_service_name" {
  description = "Name of the Cloud Run service to monitor."
  type        = string
}

variable "db_instance_name" {
  description = "Full Cloud SQL instance name (with random suffix, e.g. cloudsql-reporting-abc12345). Used for metric filters."
  type        = string

  validation {
    condition     = length(var.db_instance_name) > 0
    error_message = "db_instance_name must not be empty."
  }
}

variable "pdf_bucket_name" {
  description = "Name of the PDF reports Cloud Storage bucket."
  type        = string
}

variable "alert_email" {
  description = "Email address for alerting notifications."
  type        = string
}

variable "alert_high_error_rate_threshold" {
  description = "5xx error rate fraction threshold (e.g. 0.05 = 5%)."
  type        = number
  default     = 0.05
}

variable "alert_latency_p95_threshold_ms" {
  description = "p95 latency threshold in milliseconds."
  type        = number
  default     = 10000
}

variable "alert_sql_disk_threshold" {
  description = "Cloud SQL disk utilisation fraction threshold."
  type        = number
  default     = 0.80
}

variable "alert_sql_cpu_threshold" {
  description = "Cloud SQL CPU utilisation fraction threshold."
  type        = number
  default     = 0.90
}

variable "cloudrun_max_instances" {
  description = "Cloud Run max instances (used for instance-at-max alert)."
  type        = number
  default     = 5
}

variable "log_bucket_kms_key_name" {
  description = "Cloud KMS key resource name for CMEK encryption of Cloud Logging buckets. Must be in the same region as the buckets. Format: projects/<project>/locations/<region>/keyRings/<ring>/cryptoKeys/<key>"
  type        = string

  validation {
    condition     = length(var.log_bucket_kms_key_name) > 0
    error_message = "log_bucket_kms_key_name must not be empty. Provide a Cloud KMS key for log bucket CMEK encryption."
  }
}

variable "labels" {
  description = "Labels to apply to resources."
  type        = map(string)
  default     = {}
}
