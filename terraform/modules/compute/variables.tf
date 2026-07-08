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

variable "web_app_sku" {
  description = "App Service Plan SKU for Web App."
  type        = string
  default     = "P2v3"
}

variable "api_app_sku" {
  description = "App Service Plan SKU for API."
  type        = string
  default     = "P2v3"
}

variable "web_app_min_instances" {
  type    = number
  default = 2
}

variable "web_app_max_instances" {
  type    = number
  default = 10
}

variable "api_app_min_instances" {
  type    = number
  default = 2
}

variable "api_app_max_instances" {
  type    = number
  default = 10
}

variable "acr_sku" {
  description = "Azure Container Registry SKU."
  type        = string
  default     = "Premium"
}

variable "docker_image_web" {
  description = "Docker image name for Web App (without tag)."
  type        = string
  default     = "eshopweb"
}

variable "docker_image_api" {
  description = "Docker image name for API (without tag)."
  type        = string
  default     = "eshoppublicapi"
}

variable "docker_image_tag" {
  description = "Docker image tag. Must be a pinned tag — 'latest' is not permitted."
  type        = string
  validation {
    condition     = var.docker_image_tag != "" && var.docker_image_tag != "latest"
    error_message = "docker_image_tag must be a specific pinned tag (e.g. v1.2.3). 'latest' is not permitted."
  }
}

variable "subnet_apps_id" {
  description = "Subnet ID for Web App VNet integration."
  type        = string
}

variable "subnet_api_id" {
  description = "Subnet ID for API VNet integration."
  type        = string
}

variable "subnet_acr_id" {
  description = "Subnet ID for ACR private endpoint."
  type        = string
}

variable "appgw_subnet_cidr" {
  description = "CIDR of the App Gateway subnet — used to scope App Service inbound IP restrictions."
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network resource ID."
  type        = string
}

variable "key_vault_uri" {
  description = "Key Vault URI for app settings references."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
