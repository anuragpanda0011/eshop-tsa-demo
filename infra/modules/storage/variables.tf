variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the bucket."
  type        = string
}

variable "pdf_bucket_name_prefix" {
  description = "Prefix for the PDF bucket name. Project ID will be appended."
  type        = string
  default     = "pdf-reports"
}

variable "pdf_bucket_nearline_days" {
  description = "Days after which objects transition to NEARLINE."
  type        = number
  default     = 90
}

variable "pdf_bucket_coldline_days" {
  description = "Days after which objects transition to COLDLINE."
  type        = number
  default     = 365
}

variable "pdf_bucket_delete_days" {
  description = "Days after which objects are deleted."
  type        = number
  default     = 2555
}

variable "cors_allowed_origins" {
  description = "List of allowed CORS origins for the PDF bucket. Must not contain '*'."
  type        = list(string)

  validation {
    condition     = !contains(var.cors_allowed_origins, "*")
    error_message = "cors_allowed_origins must not contain '*'. Use explicit origins."
  }

  validation {
    condition     = length(var.cors_allowed_origins) > 0
    error_message = "cors_allowed_origins must contain at least one origin."
  }
}

variable "kms_key_name" {
  description = "Cloud KMS key resource name for CMEK encryption of all storage buckets. The GCS service account must have roles/cloudkms.cryptoKeyEncrypterDecrypter on this key. Format: projects/<project>/locations/<region>/keyRings/<ring>/cryptoKeys/<key>"
  type        = string

  validation {
    condition     = length(var.kms_key_name) > 0
    error_message = "kms_key_name must not be empty. Provide a Cloud KMS key for GCS CMEK encryption."
  }
}

variable "labels" {
  description = "Labels to apply to resources."
  type        = map(string)
  default     = {}
}
