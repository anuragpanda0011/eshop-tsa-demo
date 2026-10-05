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

variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "acr_id" {
  type = string
}

variable "acr_login_server" {
  type = string
}

variable "aca_web_id" {
  type        = string
  description = "Resource ID of the Web Container App. RBAC scoped to this resource only."
}

variable "aca_api_id" {
  type        = string
  description = "Resource ID of the API Container App. RBAC scoped to this resource only."
}

variable "aca_environment_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "managed_identity_web_id" {
  type = string
}

variable "managed_identity_api_id" {
  type = string
}

# FIX: Resource group ID for scoped Reader assignment — not subscription scope.
variable "resource_group_id" {
  type        = string
  description = "Resource ID of the deployment resource group. Reader is scoped here, not to the subscription."
}

variable "front_door_hostname" {
  type        = string
  description = "Front Door endpoint hostname used in smoke tests (referenced via GitHub vars.FRONT_DOOR_HOSTNAME)."

  validation {
    condition     = length(var.front_door_hostname) > 0 && var.front_door_hostname != "placeholder.azurefd.net"
    error_message = "front_door_hostname must be a real Front Door endpoint hostname, not a placeholder."
  }
}
