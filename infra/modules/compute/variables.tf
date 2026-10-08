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

variable "acr_georeplications" {
  description = "List of secondary regions for ACR geo-replication."
  type        = list(string)
  default     = []
}

variable "web_container_image" {
  description = "Container image for the Web (storefront) app."
  type        = string
}

variable "api_container_image" {
  description = "Container image for the PublicApi app."
  type        = string
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

variable "swa_sku_tier" {
  description = "Static Web App SKU tier."
  type        = string
  default     = "Standard"
}

variable "aca_infra_subnet_id" {
  description = "Subnet ID for the Container Apps Environment infrastructure."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints."
  type        = string
}

variable "vnet_id" {
  description = "VNet resource ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  type        = string
}

variable "app_insights_connection_string" {
  description = "Application Insights connection string."
  type        = string
  sensitive   = true
}

variable "key_vault_uri" {
  description = "URI of the Key Vault."
  type        = string
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault."
  type        = string
}

variable "web_managed_identity_id" {
  description = "Resource ID of the Web user-assigned managed identity."
  type        = string
}

variable "api_managed_identity_id" {
  description = "Resource ID of the API user-assigned managed identity."
  type        = string
}

variable "web_managed_identity_client_id" {
  description = "Client ID of the Web managed identity."
  type        = string
}

variable "api_managed_identity_client_id" {
  description = "Client ID of the API managed identity."
  type        = string
}

variable "web_managed_identity_principal_id" {
  description = "Principal ID of the Web managed identity (for ACR pull RBAC)."
  type        = string
}

variable "api_managed_identity_principal_id" {
  description = "Principal ID of the API managed identity (for ACR pull RBAC)."
  type        = string
}

variable "private_dns_zone_acr_id" {
  description = "Resource ID of the ACR private DNS zone."
  type        = string
}

variable "nat_gateway_id" {
  description = "Resource ID of the NAT gateway (informational output)."
  type        = string
  default     = ""
}

variable "redis_connection_string_secret" {
  description = "Redis connection string value (sensitive)."
  type        = string
  sensitive   = true
}

variable "catalog_db_connection_secret" {
  description = "Catalog DB connection string value (sensitive)."
  type        = string
  sensitive   = true
}

variable "identity_db_connection_secret" {
  description = "Identity DB connection string value (sensitive)."
  type        = string
  sensitive   = true
}

variable "jwt_secret_key_value" {
  description = "JWT signing key value sourced from Key Vault (sensitive). Never hardcode."
  type        = string
  sensitive   = true
}
