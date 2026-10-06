variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "sql_subnet_id" {
  type = string
}

variable "redis_subnet_id" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "sql_catalog_server_name" {
  type = string
}

variable "sql_identity_server_name" {
  type = string
}

variable "sql_catalog_db_name" {
  type = string
}

variable "sql_identity_db_name" {
  type = string
}

variable "sql_catalog_sku" {
  type    = string
  default = "GP_Gen5_4"
}

variable "sql_identity_sku" {
  type    = string
  default = "GP_Gen5_2"
}

variable "sql_backup_retention_days" {
  type    = number
  default = 35
}

variable "entra_sql_admin_object_id" {
  type = string
}

variable "entra_sql_admin_login" {
  type = string
}

variable "redis_name" {
  type = string
}

variable "redis_capacity" {
  type    = number
  default = 1
}

variable "redis_family" {
  type    = string
  default = "P"
}

variable "redis_sku_name" {
  type    = string
  default = "Premium"
}

variable "sql_private_dns_zone_id" {
  type = string
}

variable "redis_private_dns_zone_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "storage_account_id" {
  type        = string
  description = "Resource ID of the images storage account (used for RBAC scoping)"
  default     = ""
}
