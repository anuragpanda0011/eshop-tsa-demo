# ---------------------------------------------------------------------------
# Root-level variables
# ---------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure Subscription ID to deploy resources into."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID (lowercase hex, e.g. 00000000-0000-0000-0000-000000000000)."
  }
}

variable "environment" {
  description = "Deployment environment name (dev | staging | prod)."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Primary Azure region for resource deployment."
  type        = string
  default     = "eastus2"
}

variable "location_short" {
  description = "Short location code used in resource naming."
  type        = string
  default     = "eus2"
}

variable "project" {
  description = "Project identifier used in resource naming."
  type        = string
  default     = "eshoponweb"
}

# ---------------------------------------------------------------------------
# Networking variables
# ---------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "CIDR block for the Virtual Network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "Map of subnet names to CIDR blocks."
  type        = map(string)
  default = {
    appgw    = "10.0.0.0/24"
    apps     = "10.0.1.0/24"
    api      = "10.0.2.0/24"
    data     = "10.0.3.0/24"
    keyvault = "10.0.4.0/24"
    acr      = "10.0.5.0/24"
    bastion  = "10.0.255.0/27"
  }
}

# ---------------------------------------------------------------------------
# Compute variables
# ---------------------------------------------------------------------------

variable "web_app_sku" {
  description = "App Service Plan SKU for the MVC Web App."
  type        = string
  default     = "P2v3"
}

variable "api_app_sku" {
  description = "App Service Plan SKU for the Public API."
  type        = string
  default     = "P2v3"
}

variable "web_app_min_instances" {
  description = "Minimum instance count for Web App autoscale."
  type        = number
  default     = 2
}

variable "web_app_max_instances" {
  description = "Maximum instance count for Web App autoscale."
  type        = number
  default     = 10
}

variable "api_app_min_instances" {
  description = "Minimum instance count for API autoscale."
  type        = number
  default     = 2
}

variable "api_app_max_instances" {
  description = "Maximum instance count for API autoscale."
  type        = number
  default     = 10
}

variable "acr_sku" {
  description = "Azure Container Registry SKU."
  type        = string
  default     = "Premium"
}

variable "docker_image_web" {
  description = "Docker image (without tag) for the MVC Web App."
  type        = string
  default     = "eshopweb"
}

variable "docker_image_api" {
  description = "Docker image (without tag) for the Public API."
  type        = string
  default     = "eshoppublicapi"
}

variable "docker_image_tag" {
  description = "Pinned Docker image tag to deploy. Must not be 'latest'."
  type        = string
  validation {
    condition     = var.docker_image_tag != "" && var.docker_image_tag != "latest"
    error_message = "docker_image_tag must be set to a specific pinned tag (e.g. v1.2.3 or a digest). 'latest' is not permitted."
  }
}

# ---------------------------------------------------------------------------
# Database variables
# ---------------------------------------------------------------------------

variable "sql_admin_login" {
  description = "SQL Server administrator login name."
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "SQL Server administrator password. Must meet complexity requirements."
  type        = string
  sensitive   = true
}

variable "sql_aad_admin_object_id" {
  description = "Object ID of the Azure AD group or user to configure as SQL AAD Administrator."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.sql_aad_admin_object_id))
    error_message = "sql_aad_admin_object_id must be a valid UUID."
  }
}

variable "catalog_db_sku" {
  description = "SQL Database SKU for Catalog DB."
  type        = string
  default     = "GP_S_Gen5_4"
}

variable "identity_db_sku" {
  description = "SQL Database SKU for Identity DB."
  type        = string
  default     = "GP_S_Gen5_2"
}

variable "redis_sku_name" {
  description = "Azure Cache for Redis SKU name."
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Azure Cache for Redis family."
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Azure Cache for Redis capacity."
  type        = number
  default     = 2
}

# ---------------------------------------------------------------------------
# Security / Identity variables
# ---------------------------------------------------------------------------

variable "key_vault_sku" {
  description = "Key Vault SKU (standard | premium)."
  type        = string
  default     = "premium"
}

variable "tenant_id" {
  description = "Azure AD / Entra ID Tenant ID."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant_id))
    error_message = "tenant_id must be a valid UUID."
  }
}

variable "devops_object_id" {
  description = "Object ID of the DevOps / pipeline service principal for Key Vault RBAC."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.devops_object_id))
    error_message = "devops_object_id must be a valid UUID."
  }
}

# ---------------------------------------------------------------------------
# Application Gateway TLS certificate
# ---------------------------------------------------------------------------

variable "ssl_certificate_data" {
  description = "Base64-encoded PFX certificate for the Application Gateway HTTPS listener."
  type        = string
  sensitive   = true
}

variable "ssl_certificate_password" {
  description = "Password protecting the PFX certificate supplied in ssl_certificate_data."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Monitoring variables
# ---------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Log Analytics Workspace retention period in days."
  type        = number
  default     = 90
}

variable "alert_email_address" {
  description = "Email address for Azure Monitor alert notifications."
  type        = string
  default     = "ops-team@example.com"
}

# ---------------------------------------------------------------------------
# DNS / Front Door variables
# ---------------------------------------------------------------------------

variable "dns_zone_name" {
  description = "Azure DNS Zone name for the application."
  type        = string
  default     = "eshoponweb.example.com"
}

variable "front_door_sku" {
  description = "Azure Front Door SKU (Standard_AzureFrontDoor | Premium_AzureFrontDoor)."
  type        = string
  default     = "Standard_AzureFrontDoor"
}

# ---------------------------------------------------------------------------
# CI/CD variables
# ---------------------------------------------------------------------------

variable "github_organization" {
  description = "GitHub organisation or user name that owns the repository."
  type        = string
  default     = "my-org"
}

variable "github_repository" {
  description = "GitHub repository name."
  type        = string
  default     = "eShopOnWeb"
}
