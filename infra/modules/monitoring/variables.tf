variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "project" {
  description = "Project short name."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 90
}

variable "alert_email" {
  description = "Email address for alert notifications."
  type        = string
}

variable "enable_law_cmk" {
  description = <<-EOT
    Enable customer-managed key (CMK) encryption for Log Analytics Workspace.
    Requires a dedicated Log Analytics Cluster (~$400/month).
    Set to true for regulated/PII production workloads.
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
