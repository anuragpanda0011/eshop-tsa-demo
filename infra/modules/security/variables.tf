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

variable "tenant_id" {
  type = string
}

variable "kv_sku_name" {
  type    = string
  default = "standard"
}

variable "acr_sku" {
  type    = string
  default = "Premium"
}

variable "vnet_id" {
  type = string
}

variable "kv_subnet_id" {
  type = string
}

variable "kv_private_dns_zone_id" {
  type = string
}

variable "acr_private_dns_zone_id" {
  type = string
}

variable "acr_subnet_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "web_app_principal_id" {
  type = string
}

variable "api_app_principal_id" {
  type = string
}

variable "sql_catalog_connection_string" {
  type      = string
  sensitive = true
}

variable "sql_identity_connection_string" {
  type      = string
  sensitive = true
}

variable "redis_connection_string" {
  type      = string
  sensitive = true
}

variable "app_insights_connection_string" {
  type      = string
  sensitive = true
}

variable "jwt_secret_key" {
  type      = string
  sensitive = true
}

variable "storage_account_id" {
  type        = string
  description = "Resource ID of the storage account for blob data reader role"
  default     = ""
}
