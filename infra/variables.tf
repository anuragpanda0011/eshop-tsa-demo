###############################################################################
# Global
###############################################################################
variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD Tenant ID"
}

variable "location" {
  type        = string
  description = "Primary Azure region"
  default     = "eastus2"
}

variable "environment" {
  type        = string
  description = "Environment name (prod, staging, dev)"
  default     = "prod"
}

variable "project" {
  type        = string
  description = "Project short-name used in resource naming"
  default     = "eshop"
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources"
  default = {
    project     = "eShopOnWeb"
    environment = "prod"
    managed_by  = "terraform"
  }
}

###############################################################################
# Network
###############################################################################
variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "subnets" {
  type = map(object({
    address_prefix     = string
    service_endpoints  = list(string)
    delegation_name    = optional(string)
    delegation_service = optional(string)
    delegation_actions = optional(list(string))
  }))
  default = {
    snet-web = {
      address_prefix    = "10.0.1.0/24"
      service_endpoints = ["Microsoft.Web", "Microsoft.KeyVault", "Microsoft.Sql"]
      delegation_name    = "webapp-delegation"
      delegation_service = "Microsoft.Web/serverFarms"
      delegation_actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
    snet-api = {
      address_prefix    = "10.0.2.0/24"
      service_endpoints = ["Microsoft.Web", "Microsoft.KeyVault", "Microsoft.Sql"]
      delegation_name    = "api-delegation"
      delegation_service = "Microsoft.Web/serverFarms"
      delegation_actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
    snet-redis = {
      address_prefix    = "10.0.3.0/24"
      service_endpoints = []
    }
    snet-sql = {
      address_prefix    = "10.0.4.0/24"
      service_endpoints = []
    }
    snet-keyvault = {
      address_prefix    = "10.0.5.0/24"
      service_endpoints = []
    }
    snet-build = {
      address_prefix    = "10.0.6.0/24"
      service_endpoints = []
    }
    snet-mgmt = {
      address_prefix    = "10.0.7.0/24"
      service_endpoints = []
    }
    AzureBastionSubnet = {
      address_prefix    = "10.0.8.0/27"
      service_endpoints = []
    }
  }
}

###############################################################################
# Compute
###############################################################################
variable "web_app_sku_name" {
  type    = string
  default = "P2v3"
}

variable "api_app_sku_name" {
  type    = string
  default = "P1v3"
}

variable "web_min_instances" {
  type    = number
  default = 2
}

variable "web_max_instances" {
  type    = number
  default = 6
}

variable "api_min_instances" {
  type    = number
  default = 2
}

variable "api_max_instances" {
  type    = number
  default = 4
}

variable "dotnet_version" {
  type    = string
  default = "8.0"
}

###############################################################################
# Database
###############################################################################
variable "sql_catalog_sku" {
  type    = string
  default = "GP_Gen5_4"
}

variable "sql_identity_sku" {
  type    = string
  default = "GP_Gen5_2"
}

variable "sql_app_username" {
  type    = string
  default = "appUser"
}

variable "sql_catalog_db_name" {
  type    = string
  default = "catalogDatabase"
}

variable "sql_identity_db_name" {
  type    = string
  default = "identityDatabase"
}

variable "sql_backup_retention_days" {
  type    = number
  default = 35
}

###############################################################################
# Redis
###############################################################################
variable "redis_capacity" {
  type    = number
  default = 1
}

variable "redis_family" {
  type    = string
  default = "P"
}

variable "redis_sku_name" {
  type    = string
  default = "Premium"
}

###############################################################################
# Security / Key Vault
###############################################################################
variable "kv_sku_name" {
  type    = string
  default = "standard"
}

variable "entra_sql_admin_object_id" {
  type        = string
  description = "Object ID of the Entra ID group/user to set as SQL Entra Admin"
}

variable "entra_sql_admin_login" {
  type        = string
  description = "Login name for Entra ID SQL Admin"
  default     = "eshop-sql-admins"
}

###############################################################################
# Container Registry
###############################################################################
variable "acr_sku" {
  type    = string
  default = "Premium"
}

###############################################################################
# Storage
###############################################################################
variable "storage_account_replication_type" {
  type    = string
  default = "LRS"
}

###############################################################################
# Front Door / DNS
###############################################################################
variable "custom_domain_name" {
  type        = string
  description = "Custom domain for Front Door (e.g. eshop.example.com)"
  default     = "eshop.example.com"
}

variable "dns_zone_name" {
  type        = string
  description = "Azure DNS Zone name"
  default     = "example.com"
}

variable "dns_zone_resource_group" {
  type        = string
  description = "Resource group that contains the Azure DNS Zone (may differ from main RG)"
  default     = "rg-dns"
}

###############################################################################
# Monitoring
###############################################################################
variable "log_analytics_retention_days" {
  type    = number
  default = 90
}

variable "alert_action_group_email" {
  type        = string
  description = "Email address for Azure Monitor alert notifications"
  default     = "platform-ops@example.com"
}
