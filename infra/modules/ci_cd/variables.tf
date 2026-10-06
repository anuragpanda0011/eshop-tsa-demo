variable "project" {
  description = "Project short name."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "github_org" {
  description = "GitHub organisation name."
  type        = string
}

variable "github_repo_name" {
  description = "GitHub repository name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "acr_id" {
  description = "ACR resource ID."
  type        = string
}

variable "aca_web_id" {
  description = "Web Container App resource ID."
  type        = string
}

variable "aca_api_id" {
  description = "API Container App resource ID."
  type        = string
}

variable "managed_identity_id" {
  description = "Managed identity resource ID."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
