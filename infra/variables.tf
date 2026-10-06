# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure Subscription ID where all resources will be deployed."
  type        = string
}

variable "environment" {
  description = "Deployment environment (prod, staging, dev)."
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Short project name used as a naming prefix."
  type        = string
  default     = "eshoponweb"
}

variable "primary_location" {
  description = "Primary Azure region."
  type        = string
  default     = "eastus2"
}

variable "secondary_location" {
  description = "Secondary Azure region for geo-replication and DR."
  type        = string
  default     = "centralus"
}

variable "tags" {
  description = "Common resource tags applied to every resource."
  type        = map(string)
  default = {
    Project     = "eShopOnWeb"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "Address space for the primary VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "ddos_protection_plan_enabled" {
  description = "Enable Azure DDoS Network Protection plan."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Container Registry
# ---------------------------------------------------------------------------
variable "acr_sku" {
  description = "ACR SKU (Premium required for geo-replication and private endpoints)."
  type        = string
  default     = "Premium"
}

# ---------------------------------------------------------------------------
# Container Apps
# ---------------------------------------------------------------------------
variable "web_image" {
  description = <<-EOT
    Full image reference for the web frontend container app.
    Must be a SHA-tagged image (e.g. myacr.azurecr.io/eshop/web:sha-abc1234).
    No default — must be supplied by the CI/CD pipeline to prevent deploying
    a sample or mutable-tag image to production.
  EOT
  type        = string
  # No default: CI/CD must always supply a validated SHA-tagged reference.
}

variable "api_image" {
  description = <<-EOT
    Full image reference for the public API container app.
    Must be a SHA-tagged image (e.g. myacr.azurecr.io/eshop/publicapi:sha-abc1234).
    No default — must be supplied by the CI/CD pipeline.
  EOT
  type        = string
  # No default: CI/CD must always supply a validated SHA-tagged reference.
}

variable "web_min_replicas" {
  description = "Minimum replica count for ca-web."
  type        = number
  default     = 2
}

variable "web_max_replicas" {
  description = "Maximum replica count for ca-web."
  type        = number
  default     = 10
}

variable "api_min_replicas" {
  description = "Minimum replica count for ca-publicapi."
  type        = number
  default     = 2
}

variable "api_max_replicas" {
  description = "Maximum replica count for ca-publicapi."
  type        = number
  default     = 8
}

# ---------------------------------------------------------------------------
# SQL
# ---------------------------------------------------------------------------
variable "sql_admin_login" {
  description = "SQL Server administrator login name."
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "SQL Server administrator password (stored in Key Vault)."
  type        = string
  sensitive   = true
}

variable "sql_catalog_sku" {
  description = "SKU for Catalog SQL Database (Business Critical)."
  type        = string
  default     = "BC_Gen5_2"
}

variable "sql_identity_sku" {
  description = "SKU for Identity SQL Database (General Purpose)."
  type        = string
  default     = "GP_Gen5_2"
}

# ---------------------------------------------------------------------------
# Redis
# ---------------------------------------------------------------------------
variable "redis_sku" {
  description = "Redis cache SKU name."
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Redis cache family."
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis cache capacity (C1 = 1)."
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
variable "kv_sku" {
  description = "Key Vault SKU."
  type        = string
  default     = "standard"
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------
variable "log_retention_days" {
  description = "Log Analytics Workspace retention in days."
  type        = number
  default     = 90
}

variable "alert_email" {
  description = "Email address for Azure Monitor alert notifications."
  type        = string
}

variable "enable_law_cmk" {
  description = <<-EOT
    Enable customer-managed key encryption for the Log Analytics Workspace.
    Requires a dedicated Log Analytics Cluster (~$400/month additional cost).
    Set to true for production workloads handling PII or regulated data.
  EOT
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Static Web Apps
# ---------------------------------------------------------------------------
variable "swa_sku" {
  description = "Static Web Apps SKU (Free | Standard)."
  type        = string
  default     = "Standard"
}

variable "github_repo_url" {
  description = "GitHub repository URL (e.g. https://github.com/org/repo)."
  type        = string
  default     = "https://github.com/dotnet-architecture/eShopOnWeb"
}

variable "github_repo_branch" {
  description = "GitHub branch to deploy from."
  type        = string
  default     = "main"
}

# ---------------------------------------------------------------------------
# CI/CD identity
# ---------------------------------------------------------------------------
variable "github_org" {
  description = "GitHub organisation or user name (used to scope federated identity)."
  type        = string
}

variable "github_repo_name" {
  description = "GitHub repository name (without org prefix)."
  type        = string
}
