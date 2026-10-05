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

variable "log_retention_days" {
  type        = number
  default     = 90
  description = "Log Analytics Workspace retention in days. Minimum 90 days (CIS Azure benchmark)."

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "log_retention_days must be at least 90 days to meet the CIS Azure benchmark minimum retention requirement."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
