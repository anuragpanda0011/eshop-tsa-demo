variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "log_retention_days" {
  type    = number
  default = 90

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "log_retention_days must be at least 90 days (CIS Azure benchmark)."
  }
}

variable "alert_email" {
  type = string
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID used for alert scope construction."
}

variable "health_check_url" {
  type        = string
  description = "Hostname used for Application Insights availability web test (e.g. Front Door endpoint hostname)."

  validation {
    condition     = length(var.health_check_url) > 0
    error_message = "health_check_url must be a non-empty hostname."
  }
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault resource ID for CMK configuration of the LAW linked storage account."
}

variable "data_protection_key_name" {
  type        = string
  description = "Key Vault key name used for CMK on the LAW storage account."
}

variable "subnet_pe_id" {
  type        = string
  description = "Subnet ID for the private endpoint of the LAW CMK storage account."
}

variable "private_dns_zone_blob_id" {
  type        = string
  description = "Resource ID of the blob storage private DNS zone for the LAW CMK storage private endpoint."
}

variable "sampling_percentage" {
  type        = number
  default     = 20
  description = "Application Insights telemetry sampling percentage (1-100). Lower values reduce LAW ingestion to avoid daily quota breach."

  validation {
    condition     = var.sampling_percentage >= 1 && var.sampling_percentage <= 100
    error_message = "sampling_percentage must be between 1 and 100."
  }
}
