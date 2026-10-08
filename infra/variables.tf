# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure Subscription ID where all resources will be deployed."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD Tenant ID. Used to configure the azuread provider with explicit OIDC authentication."
  type        = string
}

variable "cicd_client_id" {
  description = "Client ID of the identity used by the CI/CD pipeline for azuread provider authentication (OIDC). Typically the same as AZURE_CLIENT_ID in the pipeline environment."
  type        = string
  default     = ""
}

variable "location" {
  description = "Primary Azure region for all resources."
  type        = string
  default     = "eastus2"
}

variable "location_secondary" {
  description = "Secondary Azure region for geo-replication / DR."
  type        = string
  default     = "westus2"
}

variable "environment" {
  description = "Deployment environment name (prod, staging, dev)."
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Short project name used in resource naming."
  type        = string
  default     = "eshoponweb"
}

variable "tags" {
  description = "Common resource tags applied to all resources."
  type        = map(string)
  default = {
    project     = "eShopOnWeb"
    environment = "prod"
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "Address space for the primary virtual network."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

# ---------------------------------------------------------------------------
# Compute / Container Apps
# ---------------------------------------------------------------------------
variable "web_container_image" {
  description = "Full container image reference for the Web (storefront) container app."
  type        = string
  default     = "mcr.microsoft.com/dotnet/samples:aspnetapp"
}

variable "api_container_image" {
  description = "Full container image reference for the PublicApi container app."
  type        = string
  default     = "mcr.microsoft.com/dotnet/samples:aspnetapp"
}

variable "web_min_replicas" {
  description = "Minimum replicas for the Web container app."
  type        = number
  default     = 2
}

variable "web_max_replicas" {
  description = "Maximum replicas for the Web container app."
  type        = number
  default     = 20
}

variable "api_min_replicas" {
  description = "Minimum replicas for the API container app."
  type        = number
  default     = 2
}

variable "api_max_replicas" {
  description = "Maximum replicas for the API container app."
  type        = number
  default     = 15
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
variable "sql_admin_login" {
  description = "SQL Server administrator login name (used for initial server creation only; Entra-only auth is enforced)."
  type        = string
  default     = "sqladminuser"
}

variable "sql_admin_password" {
  description = "SQL Server administrator password (used for initial server creation only). Pass via TF_VAR_sql_admin_password — never store in tfvars files."
  type        = string
  sensitive   = true
}

variable "sql_sku_name" {
  description = "SKU for Azure SQL Database (e.g. GP_Gen5_2, HS_Gen5_4)."
  type        = string
  default     = "GP_Gen5_2"
}

variable "sql_max_size_gb" {
  description = "Maximum database size in GB."
  type        = number
  default     = 32
}

# ---------------------------------------------------------------------------
# Redis
# ---------------------------------------------------------------------------
variable "redis_sku" {
  description = "Redis Cache SKU (Basic, Standard, Premium)."
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Redis Cache family (C for Basic/Standard, P for Premium)."
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis Cache capacity (0-6 for C family)."
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# Front Door / DNS
# ---------------------------------------------------------------------------
variable "custom_domain_name" {
  description = "Custom domain for the storefront (e.g. shop.contoso.com). Leave empty to skip custom domain."
  type        = string
  default     = ""
}

variable "dns_zone_name" {
  description = "Azure DNS public zone name (e.g. contoso.com). Leave empty to skip DNS zone management."
  type        = string
  default     = ""
}

variable "dns_zone_resource_group" {
  description = "Resource group containing the Azure DNS zone (may differ from main RG)."
  type        = string
  default     = ""
}

variable "front_door_profile_resource_guid" {
  description = "Resource GUID of the Front Door profile. Used in the APIM global policy to validate the X-Azure-FDID header. Obtain from the front_door_profile_resource_guid output after first apply, then set this variable for subsequent applies."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Container Registry
# ---------------------------------------------------------------------------
variable "acr_georeplications" {
  description = "List of locations for ACR geo-replication. Defaults to empty (no replication). Set explicitly to opt in and control cost."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Static Web Apps
# ---------------------------------------------------------------------------
variable "swa_sku_tier" {
  description = "Static Web Apps pricing tier (Free or Standard)."
  type        = string
  default     = "Standard"
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC
# ---------------------------------------------------------------------------
variable "github_org" {
  description = "GitHub organisation or user name for OIDC federation."
  type        = string
  default     = "my-org"
}

variable "github_repo" {
  description = "GitHub repository name for OIDC federation."
  type        = string
  default     = "eShopOnWeb"
}

# ---------------------------------------------------------------------------
# API Management
# ---------------------------------------------------------------------------
variable "apim_publisher_email" {
  description = "Publisher contact email for Azure API Management."
  type        = string
  default     = "api-admin@contoso.com"
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------
variable "log_retention_days" {
  description = "Retention period for Log Analytics workspace (days)."
  type        = number
  default     = 90
}

variable "alert_email" {
  description = "Email address for monitoring alert notifications."
  type        = string
  default     = "ops-team@contoso.com"
}

# ---------------------------------------------------------------------------
# Secrets (never store values in tfvars; use TF_VAR_* environment variables)
# ---------------------------------------------------------------------------
variable "jwt_secret_key_value" {
  description = "Initial JWT signing key value to store in Key Vault. Pass via TF_VAR_jwt_secret_key_value from the CI/CD secrets store. Rotate immediately after first deploy."
  type        = string
  sensitive   = true
}

variable "health_probe_token" {
  description = "Shared secret token sent as X-Health-Probe-Token header in availability web tests. Pass via TF_VAR_health_probe_token. Configure Front Door/application to validate this header on /health requests."
  type        = string
  sensitive   = true
}
