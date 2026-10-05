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

variable "tags" {
  type    = map(string)
  default = {}
}

variable "subnet_pe_id" {
  type = string
}

variable "subnet_redis_id" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "sql_sku" {
  type    = string
  default = "GP_Gen5_2"
}

variable "sql_max_size_gb" {
  type    = number
  default = 32
}

variable "sql_zone_redundant" {
  type    = bool
  default = true
}

variable "redis_sku" {
  type    = string
  default = "Standard"
}

variable "redis_family" {
  type    = string
  default = "C"
}

variable "redis_capacity" {
  type    = number
  default = 1
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "private_dns_zone_sql_id" {
  type = string
}

variable "private_dns_zone_redis_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "managed_identity_web_principal_id" {
  type = string
}

variable "managed_identity_api_principal_id" {
  type = string
}

variable "aad_sql_admin_object_id" {
  type        = string
  description = "Object ID of the AAD group or user to set as SQL AAD administrator."

  validation {
    condition     = length(var.aad_sql_admin_object_id) > 0
    error_message = "aad_sql_admin_object_id must be a non-empty AAD object ID."
  }
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID for AAD SQL admin configuration."

  validation {
    condition     = length(var.tenant_id) > 0
    error_message = "tenant_id must be provided."
  }
}

variable "audit_storage_primary_blob_endpoint" {
  type        = string
  description = "Primary blob endpoint of the immutable audit storage account."
}

variable "audit_storage_account_id" {
  type        = string
  description = "Resource ID of the audit storage account."
}

variable "audit_storage_subscription_id" {
  type        = string
  default     = ""
  description = "Subscription ID of the audit storage account. Pass var.subscription_id from root."
}
