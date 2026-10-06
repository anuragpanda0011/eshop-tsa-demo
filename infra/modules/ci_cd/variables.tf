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

variable "web_app_id" {
  type        = string
  description = "Resource ID of the Web App Service"
}

variable "api_app_id" {
  type        = string
  description = "Resource ID of the API App Service"
}

variable "web_app_hostname" {
  type        = string
  description = "Default hostname of the Web App"
}

variable "api_app_hostname" {
  type        = string
  description = "Default hostname of the API App"
}

variable "custom_domain_name" {
  type        = string
  description = "Custom domain for Front Door"
}

variable "dns_zone_name" {
  type        = string
  description = "Azure DNS Zone name"
}

variable "dns_zone_resource_group" {
  type        = string
  description = "Resource group containing the DNS zone"
}

variable "log_analytics_workspace_id" {
  type = string
}
