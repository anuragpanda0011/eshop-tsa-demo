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

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for diagnostic settings."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints."
  type        = string
}

variable "vnet_id" {
  description = "VNet resource ID."
  type        = string
}

variable "github_org" {
  description = "GitHub organisation for OIDC."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository for OIDC."
  type        = string
}

variable "jwt_secret_key_value" {
  description = "Initial JWT signing key value to store in Key Vault. Must be supplied as a pipeline secret — never hardcode. Rotate immediately post-deploy."
  type        = string
  sensitive   = true
}
