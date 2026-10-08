variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "project" {
  description = "Project name for naming."
  type        = string
}

variable "environment" {
  description = "Environment name for naming."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Log Analytics workspace retention in days."
  type        = number
  default     = 90
}

variable "alert_email" {
  description = "Email address for alert notifications."
  type        = string
}

variable "storefront_url" {
  description = "Public URL of the storefront for availability web test."
  type        = string
  default     = ""
}

variable "health_probe_token" {
  description = "Shared secret token sent as X-Health-Probe-Token header in availability web tests. Configure the application or Front Door to validate this header on /health requests."
  type        = string
  sensitive   = true
}
