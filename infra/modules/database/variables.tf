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

variable "sql_admin_login" {
  description = "SQL administrator login."
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "SQL administrator password."
  type        = string
  sensitive   = true
}

variable "sql_catalog_sku" {
  description = "SKU for Catalog SQL DB."
  type        = string
  default     = "BC_Gen5_2"
}

variable "sql_identity_sku" {
  description = "SKU for Identity SQL DB."
  type        = string
  default     = "GP_Gen5_2"
}

variable "redis_sku" {
  description = "Redis cache SKU name."
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Redis cache family."
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis cache capacity."
  type        = number
  default     = 1
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for Private Endpoints."
  type        = string
}

variable "vnet_id" {
  description = "VNet resource ID."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID to store connection strings."
  type        = string
}

variable "managed_identity_principal_id" {
  description = "Principal ID of the managed identity for RBAC."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
