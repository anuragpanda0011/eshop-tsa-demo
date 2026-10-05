# ── Global ────────────────────────────────────────────────────────────────────
variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID where all resources will be deployed."
}

variable "location" {
  type        = string
  default     = "eastus2"
  description = "Primary Azure region for resource deployment."
}

variable "location_secondary" {
  type        = string
  default     = "westus2"
  description = "Secondary Azure region used for ACR geo-replication and DR."
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Deployment environment label (prod, staging, dev)."
}

variable "project" {
  type        = string
  default     = "eshoponweb"
  description = "Project name used as a prefix for all resource names."
}

variable "tags" {
  type = map(string)
  default = {
    project     = "eshoponweb"
    environment = "prod"
    managed_by  = "terraform"
  }
  description = "Common tags applied to all resources."
}

# ── Networking ────────────────────────────────────────────────────────────────
variable "vnet_address_space" {
  type        = list(string)
  default     = ["10.10.0.0/16"]
  description = "Address space for the primary virtual network."
}

variable "subnet_aca_infra_cidr" {
  type    = string
  default = "10.10.0.0/23"
}

variable "subnet_aca_apps_cidr" {
  type    = string
  default = "10.10.2.0/23"
}

variable "subnet_pe_cidr" {
  type    = string
  default = "10.10.4.0/24"
}

variable "subnet_appgw_cidr" {
  type    = string
  default = "10.10.5.0/26"
}

variable "subnet_redis_cidr" {
  type    = string
  default = "10.10.6.0/27"
}

variable "subnet_agents_cidr" {
  type    = string
  default = "10.10.7.0/26"
}

variable "subnet_bastion_cidr" {
  type    = string
  default = "10.10.8.0/27"
}

variable "subnet_apim_cidr" {
  type        = string
  default     = "10.10.9.0/27"
  description = "CIDR block for the dedicated APIM subnet (/27 minimum for External VNet mode)."
}

# ── DNS ───────────────────────────────────────────────────────────────────────
variable "custom_domain" {
  type        = string
  default     = "shop.contoso.com"
  description = "Custom domain for the storefront (CNAME to Front Door)."
}

variable "dns_zone_name" {
  type        = string
  default     = "contoso.com"
  description = "Azure DNS public zone name."
}

variable "dns_zone_resource_group" {
  type        = string
  default     = "rg-dns"
  description = "Resource group containing the public DNS zone."
}

# ── Compute ───────────────────────────────────────────────────────────────────
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

variable "web_image" {
  type        = string
  description = "Container image for the Web app. Must use a pinned tag or digest — not ':latest'."

  validation {
    condition     = !endswith(var.web_image, ":latest")
    error_message = "web_image must not use the ':latest' floating tag. Use a pinned version tag or @sha256 digest."
  }
}

variable "api_image" {
  type        = string
  description = "Container image for the API app. Must use a pinned tag or digest — not ':latest'."

  validation {
    condition     = !endswith(var.api_image, ":latest")
    error_message = "api_image must not use the ':latest' floating tag. Use a pinned version tag or @sha256 digest."
  }
}

# ── Static Web App Authentication ─────────────────────────────────────────────
variable "swa_aad_client_id" {
  type        = string
  description = "Azure AD App Registration client ID for Static Web App AAD authentication. Required — create a dedicated app registration with the SWA redirect URI configured."
}

variable "swa_aad_client_secret" {
  type        = string
  sensitive   = true
  description = "Azure AD App Registration client secret for Static Web App AAD authentication. Use TF_VAR_swa_aad_client_secret environment variable — do not commit to tfvars."
}

# ── Database ──────────────────────────────────────────────────────────────────
variable "aad_sql_admin_object_id" {
  type        = string
  description = "Object ID of the AAD group to set as SQL AAD administrator. Required — use a dedicated AAD group, not an individual user or managed identity."

  validation {
    condition     = length(var.aad_sql_admin_object_id) > 0
    error_message = "aad_sql_admin_object_id is required and must be a non-empty AAD object ID."
  }
}

variable "sql_sku" {
  type        = string
  default     = "GP_Gen5_2"
  description = "Azure SQL Database SKU."
}

variable "sql_max_size_gb" {
  type    = number
  default = 32
}

variable "sql_zone_redundant" {
  type    = bool
  default = true
}

# ── Redis ─────────────────────────────────────────────────────────────────────
variable "redis_sku" {
  type    = string
  default = "Standard"
}

variable "redis_family" {
  type    = string
  default = "C"
}

variable "redis_capacity" {
  type    = number
  default = 1
}

# ── APIM ──────────────────────────────────────────────────────────────────────
variable "apim_publisher_email" {
  type        = string
  description = "Publisher email for Azure API Management."
}

variable "apim_publisher_name" {
  type        = string
  default     = "eShopOnWeb Team"
  description = "Publisher name for Azure API Management."
}

variable "apim_sku" {
  type        = string
  default     = "Standard_1"
  description = "APIM SKU. Defaults to Standard_1 (production-grade with SLA). Developer_1 must not be used in production."

  validation {
    condition     = !(var.apim_sku == "Developer_1" && var.environment == "prod")
    error_message = "Developer_1 SKU has no SLA and must not be used when environment is 'prod'. Use Standard_1 or higher."
  }
}

variable "apim_tenant_id" {
  type        = string
  description = "Azure AD tenant ID used to construct the tenant-specific APIM JWT validation issuer URL."
}

variable "apim_audience" {
  type        = string
  description = "Application ID URI used in APIM JWT audience validation (e.g. api://<app-registration-id>)."
}

# ── Static Web Apps ───────────────────────────────────────────────────────────
variable "swa_sku_tier" {
  type    = string
  default = "Standard"
}

variable "github_repo_url" {
  type        = string
  default     = "https://github.com/contoso/eShopOnWeb"
  description = "GitHub repository URL for Static Web Apps integration."
}

variable "github_branch" {
  type    = string
  default = "main"
}

# ── Monitoring ────────────────────────────────────────────────────────────────
variable "log_retention_days" {
  type        = number
  default     = 90
  description = "Log Analytics and Application Insights retention in days. Minimum 90 (CIS benchmark)."

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "log_retention_days must be at least 90 days to meet CIS Azure benchmark requirements."
  }
}

variable "alert_email" {
  type        = string
  description = "Email address for monitoring alerts."
}

variable "log_analytics_workspace_guid" {
  type        = string
  description = "Log Analytics Workspace GUID (not resource ID) required for NSG flow log traffic analytics. Obtain after workspace creation: terraform output -raw log_analytics_workspace_guid or from Azure portal."
  default     = ""
}

variable "app_insights_sampling_percentage" {
  type        = number
  default     = 20
  description = "Application Insights telemetry sampling percentage (1-100). Lower values reduce LAW ingestion volume. 20 is recommended for production to stay within daily quota."

  validation {
    condition     = var.app_insights_sampling_percentage >= 1 && var.app_insights_sampling_percentage <= 100
    error_message = "app_insights_sampling_percentage must be between 1 and 100."
  }
}

# ── CI/CD ─────────────────────────────────────────────────────────────────────
variable "github_org" {
  type        = string
  description = "GitHub organisation for OIDC federated identity."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name for OIDC federated identity."
}
