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

variable "github_org" {
  description = "GitHub organisation name."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "acr_id" {
  description = "Resource ID of the Container Registry."
  type        = string
}

variable "acr_login_server" {
  description = "Login server URL of the Container Registry."
  type        = string
}

variable "web_container_app_id" {
  description = "Resource ID of the Web container app."
  type        = string
}

variable "api_container_app_id" {
  description = "Resource ID of the API container app."
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the main resource group."
  type        = string
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  type        = string
}

variable "cicd_service_principal_object_id" {
  description = "Object ID of the CI/CD service principal (from AAD). Must be a non-empty GUID."
  type        = string

  validation {
    condition     = length(var.cicd_service_principal_object_id) > 0
    error_message = "cicd_service_principal_object_id must be a non-empty AAD object ID (GUID)."
  }
}
