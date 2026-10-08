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

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for diagnostic settings."
  type        = string
}

variable "custom_domain_name" {
  description = "Custom domain for the storefront (optional)."
  type        = string
  default     = ""
}

variable "dns_zone_name" {
  description = "Azure DNS public zone name (optional)."
  type        = string
  default     = ""
}

variable "dns_zone_resource_group" {
  description = "Resource group of the DNS zone (optional)."
  type        = string
  default     = ""
}

variable "web_ca_fqdn" {
  description = "FQDN of the Web Container App (injected after compute module creates it). Used as Front Door origin."
  type        = string
  default     = ""
}

variable "apim_publisher_email" {
  description = "Publisher email for API Management."
  type        = string
}

variable "front_door_profile_resource_guid" {
  description = "Resource GUID of the Front Door profile. Used in APIM global policy to validate X-Azure-FDID header. Obtain after first apply from the front_door_profile_resource_guid output."
  type        = string
  default     = ""
}
