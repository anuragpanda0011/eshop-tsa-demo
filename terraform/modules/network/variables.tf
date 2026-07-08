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

variable "vnet_address_space" {
  description = "CIDR block for the Virtual Network."
  type        = string
}

variable "subnet_cidrs" {
  description = "Map of subnet key to CIDR block."
  type        = map(string)
}

variable "dns_zone_name" {
  description = "Azure DNS Zone name."
  type        = string
}

variable "front_door_sku" {
  description = "Azure Front Door SKU."
  type        = string
  default     = "Standard_AzureFrontDoor"
}

variable "web_app_hostname" {
  description = "Default hostname of the MVC Web App (used as App Gateway backend)."
  type        = string
  default     = ""
}

variable "api_app_hostname" {
  description = "Default hostname of the Public API (used as App Gateway backend)."
  type        = string
  default     = ""
}

variable "ssl_certificate_data" {
  description = "Base64-encoded PFX certificate for the Application Gateway HTTPS listener."
  type        = string
  sensitive   = true
}

variable "ssl_certificate_password" {
  description = "Password protecting the PFX certificate."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
