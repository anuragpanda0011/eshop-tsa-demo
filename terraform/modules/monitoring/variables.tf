variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource naming."
  type        = string
}

variable "log_retention_days" {
  description = "Log Analytics Workspace retention period in days."
  type        = number
  default     = 90
}

variable "alert_email_address" {
  description = "Email address for alert notifications."
  type        = string
}

variable "web_app_id" {
  description = "Resource ID of the Web App Service."
  type        = string
}

variable "api_app_id" {
  description = "Resource ID of the API App Service."
  type        = string
}

variable "catalog_sql_id" {
  description = "Resource ID of the Catalog SQL Server."
  type        = string
}

variable "redis_id" {
  description = "Resource ID of the Azure Cache for Redis."
  type        = string
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
