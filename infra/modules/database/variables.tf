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

variable "zone_primary" {
  description = "Primary GCP zone for the Cloud SQL instance."
  type        = string
}

variable "zone_secondary" {
  description = "Secondary GCP zone for the Cloud SQL HA standby."
  type        = string
}

variable "vpc_id" {
  description = "VPC network resource ID (self_link) for Cloud SQL private IP."
  type        = string
}

variable "db_instance_name" {
  description = "Name of the Cloud SQL instance."
  type        = string

  validation {
    condition     = length(var.db_instance_name) > 0
    error_message = "db_instance_name must not be empty."
  }
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-g1-small"
}

variable "db_postgres_version" {
  description = "PostgreSQL version."
  type        = string
  default     = "POSTGRES_15"
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string

  validation {
    condition     = length(var.db_name) > 0
    error_message = "db_name must not be empty."
  }
}

variable "db_user" {
  description = "PostgreSQL application user name."
  type        = string

  validation {
    condition     = length(var.db_user) > 0
    error_message = "db_user must not be empty."
  }
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 7
}

variable "db_pitr_days" {
  description = "Days of PITR transaction log retention."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on the Cloud SQL instance."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to resources."
  type        = map(string)
  default     = {}
}
