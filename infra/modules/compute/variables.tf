variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "location_secondary" {
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

variable "subnet_aca_infra_id" {
  type = string
}

variable "subnet_apim_id" {
  type        = string
  description = "Subnet ID for the APIM External VNet integration."
}

variable "vnet_id" {
  type = string
}

variable "subnet_pe_id" {
  type = string
}

variable "private_dns_zone_acr_id" {
  type = string
}

variable "private_dns_zone_blob_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "key_vault_uri" {
  type = string
}

variable "managed_identity_web_id" {
  type = string
}

variable "managed_identity_api_id" {
  type = string
}

variable "managed_identity_apim_id" {
  type        = string
  description = "Resource ID of the dedicated APIM user-assigned managed identity. Must be separate from managed_identity_api_id."
}

variable "managed_identity_web_client_id" {
  type = string
}

variable "managed_identity_api_client_id" {
  type = string
}

variable "managed_identity_web_principal_id" {
  type = string
}

variable "managed_identity_api_principal_id" {
  type = string
}

variable "app_insights_connection_string" {
  type      = string
  sensitive = true
}

variable "app_insights_secret_name" {
  type        = string
  description = "Name of the Key Vault secret holding the App Insights connection string."
  default     = "appinsights-connection-string"
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "web_image" {
  type        = string
  description = "Container image for the Web app. Must be a pinned digest reference."

  validation {
    condition     = !endswith(var.web_image, ":latest") && (contains(split(":", var.web_image), length(split(":", var.web_image)) > 1 ? split(":", var.web_image)[1] : "") || strcontains(var.web_image, "@sha256:"))
    error_message = "web_image must use a pinned tag or digest. Floating ':latest' is not permitted."
  }
}

variable "api_image" {
  type        = string
  description = "Container image for the API app. Must be a pinned digest reference."

  validation {
    condition     = !endswith(var.api_image, ":latest") && (contains(split(":", var.api_image), length(split(":", var.api_image)) > 1 ? split(":", var.api_image)[1] : "") || strcontains(var.api_image, "@sha256:"))
    error_message = "api_image must use a pinned tag or digest. Floating ':latest' is not permitted."
  }
}

variable "web_min_replicas" {
  type    = number
  default = 2
}

variable "web_max_replicas" {
  type    = number
  default = 20
}

variable "api_min_replicas" {
  type    = number
  default = 2
}

variable "api_max_replicas" {
  type    = number
  default = 15
}

variable "web_cpu" {
  type    = string
  default = "1.0"
}

variable "web_memory" {
  type    = string
  default = "2Gi"
}

variable "api_cpu" {
  type    = string
  default = "0.75"
}

variable "api_memory" {
  type    = string
  default = "1.5Gi"
}

variable "github_repo_url" {
  type    = string
  default = ""
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "swa_sku_tier" {
  type    = string
  default = "Standard"
}

# FIX: Added AAD authentication variables for Static Web App.
variable "swa_aad_client_id" {
  type        = string
  description = "Azure AD App Registration client ID for Static Web App AAD authentication. Required to enforce authentication via Terraform."
}

variable "swa_aad_client_secret" {
  type        = string
  sensitive   = true
  description = "Azure AD App Registration client secret for Static Web App AAD authentication. Stored as a SWA application secret."
}

variable "apim_publisher_email" {
  type = string
}

variable "apim_publisher_name" {
  type = string
}

variable "apim_sku" {
  type        = string
  default     = "Standard_1"
  description = "APIM SKU. Defaults to Standard_1 (production-grade with SLA). Developer_1 is rejected in production environments."

  validation {
    condition     = !(var.apim_sku == "Developer_1")
    error_message = "Developer_1 SKU has no SLA and must not be used in production. Use Standard_1 or higher."
  }
}

variable "apim_tenant_id" {
  type        = string
  description = "Azure AD tenant ID for APIM JWT validation."
}

variable "apim_audience" {
  type        = string
  description = "Application ID URI for JWT audience validation in APIM policy."
}

variable "custom_domain" {
  type    = string
  default = "shop.contoso.com"
}

variable "front_door_id" {
  type        = string
  default     = ""
  description = "Resource ID of the Front Door profile."
}

variable "nat_gateway_id" {
  type        = string
  default     = ""
  description = "Resource ID of the NAT gateway."
}

variable "data_protection_key_id" {
  type        = string
  default     = ""
  description = "Key Vault key ID (versioned) for ASP.NET Data Protection ring encryption env var."
}

variable "data_protection_key_name" {
  type        = string
  default     = "data-protection-key"
  description = "Key Vault key name for the storage account CMK configuration."
}
