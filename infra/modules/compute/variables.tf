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

variable "web_subnet_id" {
  type = string
}

variable "api_subnet_id" {
  type = string
}

variable "web_app_sku_name" {
  type    = string
  default = "P2v3"
}

variable "api_app_sku_name" {
  type    = string
  default = "P1v3"
}

variable "dotnet_version" {
  type    = string
  default = "8.0"
}

variable "web_min_instances" {
  type    = number
  default = 2
}

variable "web_max_instances" {
  type    = number
  default = 6
}

variable "api_min_instances" {
  type    = number
  default = 2
}

variable "api_max_instances" {
  type    = number
  default = 4
}

variable "key_vault_uri" {
  type        = string
  description = "Key Vault URI passed to app settings"
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "storage_account_replication_type" {
  type    = string
  default = "LRS"
}

variable "alert_action_group_email" {
  type        = string
  description = "Email address to notify on autoscale events"
}
