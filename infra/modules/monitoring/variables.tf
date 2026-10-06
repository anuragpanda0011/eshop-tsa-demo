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

variable "log_analytics_retention_days" {
  type    = number
  default = 90
}

variable "alert_action_group_email" {
  type = string

  validation {
    condition     = length(var.alert_action_group_email) > 0
    error_message = "alert_action_group_email must not be empty."
  }
}

variable "web_app_id" {
  type        = string
  description = "Resource ID of the Web App Service (for alert scoping). Empty string skips alert creation."
  default     = ""
}

variable "api_app_id" {
  type        = string
  description = "Resource ID of the API App Service (for alert scoping). Empty string skips alert creation."
  default     = ""
}

variable "web_service_plan_id" {
  type        = string
  description = "Resource ID of the Web App Service Plan. Empty string skips alert creation."
  default     = ""
}

variable "web_app_hostname" {
  type        = string
  description = "Default hostname of the Web App. Empty string skips web test creation."
  default     = ""
}

variable "api_app_hostname" {
  type        = string
  description = "Default hostname of the API App. Empty string skips web test creation."
  default     = ""
}
