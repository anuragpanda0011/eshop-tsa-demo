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

variable "sql_admin_login" {
  description = "SQL Server administrator login."
  type        = string
}

variable "sql_admin_password" {
  description = "SQL Server administrator password."
  type        = string
  sensitive   = true
}

variable "sql_aad_admin_object_id" {
  description = "Object ID of the Azure AD group or user to configure as SQL AAD Administrator."
  type        = string
}

variable "catalog_db_sku" {
  description = "SQL Database SKU for Catalog DB."
  type        = string
  default     = "GP_S_Gen5_4"
}

variable "identity_db_sku" {
  description = "SQL Database SKU for Identity DB."
  type        = string
  default     = "GP_S_Gen5_2"
}

variable "redis_sku_name" {
  description = "Redis SKU name."
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Redis family."
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis capacity."
  type        = number
  default     = 2
}

variable "subnet_data_id" {
  description = "Subnet ID for data private endpoints."
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network resource ID."
  type        = string
}

variable "log_analytics_id" {
  description = "Log Analytics Workspace resource ID."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID — used for storage CMK."
  type        = string
}

variable "key_vault_key_id" {
  description = "Key Vault key ID for storage account customer-managed key."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
