variable "resource_group_name" {
  description = "Primary resource group name."
  type        = string
}

variable "secondary_resource_group_name" {
  description = "Secondary resource group name."
  type        = string
}

variable "location" {
  description = "Primary Azure region."
  type        = string
}

variable "secondary_location" {
  description = "Secondary Azure region for ACR geo-replication."
  type        = string
}

variable "project" {
  description = "Project short name."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "acr_sku" {
  description = "ACR SKU."
  type        = string
  default     = "Premium"
}

variable "web_image" {
  description = "Web frontend container image (must be SHA-tagged)."
  type        = string
}

variable "api_image" {
  description = "API container image (must be SHA-tagged)."
  type        = string
}

variable "web_min_replicas" {
  description = "Web min replicas."
  type        = number
  default     = 2
}

variable "web_max_replicas" {
  description = "Web max replicas."
  type        = number
  default     = 10
}

variable "api_min_replicas" {
  description = "API min replicas."
  type        = number
  default     = 2
}

variable "api_max_replicas" {
  description = "API max replicas."
  type        = number
  default     = 8
}

variable "aca_infra_subnet_id" {
  description = "Subnet ID for ACA infrastructure."
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

variable "managed_identity_id" {
  description = "User-assigned managed identity resource ID."
  type        = string
}

variable "managed_identity_client_id" {
  description = "User-assigned managed identity client ID."
  type        = string
}

variable "managed_identity_principal_id" {
  description = "User-assigned managed identity principal ID."
  type        = string
}

variable "key_vault_uri" {
  description = "Key Vault URI."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID."
  type        = string
}

variable "app_insights_connection_string" {
  description = "Application Insights connection string."
  type        = string
  sensitive   = true
}

variable "catalog_sql_connection_kv_secret_name" {
  description = "KV secret name for catalog DB connection string."
  type        = string
}

variable "identity_sql_connection_kv_secret_name" {
  description = "KV secret name for identity DB connection string."
  type        = string
}

variable "redis_connection_kv_secret_name" {
  description = "KV secret name for Redis connection string."
  type        = string
}

variable "swa_sku" {
  description = "Static Web Apps SKU."
  type        = string
  default     = "Standard"
}

variable "github_repo_url" {
  description = "GitHub repository URL."
  type        = string
}

variable "github_repo_branch" {
  description = "GitHub repository branch."
  type        = string
  default     = "main"
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
