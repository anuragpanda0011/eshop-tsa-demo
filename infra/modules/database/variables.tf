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

variable "sql_admin_login" {
  description = "SQL administrator login (used for initial server creation only; Entra-only auth is enforced)."
  type        = string
}

variable "sql_admin_password" {
  description = "SQL administrator password (used for initial server creation only; Entra-only auth is enforced post-deploy)."
  type        = string
  sensitive   = true
}

variable "sql_sku_name" {
  description = "Azure SQL Database SKU name."
  type        = string
  default     = "GP_Gen5_2"
}

variable "sql_max_size_gb" {
  description = "Maximum database size in GB."
  type        = number
  default     = 32
}

variable "redis_sku" {
  description = "Redis Cache SKU (Basic, Standard, Premium)."
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Redis Cache family."
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis Cache capacity."
  type        = number
  default     = 1
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints."
  type        = string
}

variable "vnet_id" {
  description = "VNet resource ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID for storing connection string secrets."
  type        = string
}

variable "private_dns_zone_sql_id" {
  description = "Resource ID of the SQL private DNS zone."
  type        = string
}

variable "private_dns_zone_redis_id" {
  description = "Resource ID of the Redis private DNS zone."
  type        = string
}
