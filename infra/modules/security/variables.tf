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

variable "kv_sku" {
  description = "Key Vault SKU."
  type        = string
  default     = "standard"
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints."
  type        = string
}

variable "vnet_id" {
  description = "VNet resource ID."
  type        = string
}

variable "sql_admin_password" {
  description = "SQL administrator password to store in Key Vault."
  type        = string
  sensitive   = true
}

variable "sql_admin_login" {
  description = "SQL administrator login to store in Key Vault."
  type        = string
  sensitive   = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID for diagnostics."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
