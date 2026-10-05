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
  type        = string
  description = "Subnet ID for private endpoints."
}

variable "vnet_id" {
  type        = string
  description = "Virtual network resource ID."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics Workspace resource ID for diagnostic settings."
}

variable "tenant_id" {
  type        = string
  description = "Azure Active Directory tenant ID."
}

variable "current_object_id" {
  type        = string
  description = "Object ID of the current deploying principal (Terraform SP or user)."
}

variable "private_dns_zone_keyvault_id" {
  type        = string
  description = "Resource ID of the Key Vault private DNS zone (from network module)."
}

variable "private_dns_zone_blob_id" {
  type        = string
  description = "Resource ID of the blob storage private DNS zone (from network module), used for audit storage private endpoint."
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID, used for constructing scope references."
}
