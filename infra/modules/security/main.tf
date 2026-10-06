data "azurerm_client_config" "current" {}

###############################################################################
# Azure Key Vault
###############################################################################
resource "azurerm_key_vault" "main" {
  name                          = "kv-${var.project}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = var.kv_sku_name
  enable_rbac_authorization     = true
  soft_delete_retention_days    = 90
  purge_protection_enabled      = true
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

###############################################################################
# Key Vault RBAC — Terraform runner
# Scoped to Key Vault Secrets Officer (not Administrator) so the pipeline can
# read and write secrets but cannot manage keys or certificates.
# IMPORTANT: After initial provisioning, remove this role assignment from the
# pipeline service principal and rely on break-glass access only.
###############################################################################
resource "azurerm_role_assignment" "kv_secrets_officer_terraform" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

###############################################################################
# Key Vault RBAC — Web App Managed Identity (Secrets User — read-only)
###############################################################################
resource "azurerm_role_assignment" "kv_secrets_web" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.web_app_principal_id
}

resource "azurerm_role_assignment" "kv_secrets_api" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.api_app_principal_id
}

###############################################################################
# Key Vault Secrets
# NOTE: Secret values transit through Terraform state as sensitive entries.
# State is encrypted at rest in Azure Blob. Ensure strict RBAC on the tfstate
# storage account and enable Defender for Storage.
# For zero-secret-in-state, pre-create secrets outside Terraform and reference
# them with: data "azurerm_key_vault_secret" "name" { ... }
###############################################################################
resource "azurerm_key_vault_secret" "sql_catalog_connection_string" {
  name         = "AZURE-SQL-CATALOG-CONNECTION-STRING"
  value        = var.sql_catalog_connection_string
  key_vault_id = azurerm_key_vault.main.id
  content_type = "connection-string"
  tags         = var.tags

  depends_on = [azurerm_role_assignment.kv_secrets_officer_terraform]
}

resource "azurerm_key_vault_secret" "sql_identity_connection_string" {
  name         = "AZURE-SQL-IDENTITY-CONNECTION-STRING"
  value        = var.sql_identity_connection_string
  key_vault_id = azurerm_key_vault.main.id
  content_type = "connection-string"
  tags         = var.tags

  depends_on = [azurerm_role_assignment.kv_secrets_officer_terraform]
}

resource "azurerm_key_vault_secret" "redis_connection_string" {
  name         = "AZURE-REDIS-CONNECTION-STRING"
  value        = var.redis_connection_string
  key_vault_id = azurerm_key_vault.main.id
  content_type = "connection-string"
  tags         = var.tags

  depends_on = [azurerm_role_assignment.kv_secrets_officer_terraform]
}

resource "azurerm_key_vault_secret" "app_insights_connection_string" {
  name         = "AZURE-APPINSIGHTS-CONNECTION-STRING"
  value        = var.app_insights_connection_string
  key_vault_id = azurerm_key_vault.main.id
  content_type = "connection-string"
  tags         = var.tags

  depends_on = [azurerm_role_assignment.kv_secrets_officer_terraform]
}

resource "azurerm_key_vault_secret" "jwt_secret_key" {
  name         = "JWT-SECRET-KEY"
  value        = var.jwt_secret_key
  key_vault_id = azurerm_key_vault.main.id
  content_type = "secret"
  tags         = var.tags

  depends_on = [azurerm_role_assignment.kv_secrets_officer_terraform]
}

###############################################################################
# Key Vault Private Endpoint
###############################################################################
resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.kv_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-group"
    private_dns_zone_ids = [var.kv_private_dns_zone_id]
  }
}

###############################################################################
# Azure Container Registry
###############################################################################
resource "azurerm_container_registry" "main" {
  name                          = "cr${var.project}${var.environment}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.acr_sku
  admin_enabled                 = false
  public_network_access_enabled = false
  zone_redundancy_enabled       = true
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  retention_policy {
    days    = 30
    enabled = true
  }

  trust_policy {
    enabled = true
  }

  network_rule_set {
    default_action = "Deny"
  }
}

###############################################################################
# Azure Policy Assignment — Enforce ACR image tag immutability
# Built-in policy: "Azure Container Registry should have image tag immutability enabled"
# Policy definition ID: 9b3b6b3a-1955-4437-9152-8851b50dfeb0
###############################################################################
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_resource_group_policy_assignment" "acr_immutable_tags" {
  name                 = "acr-immutable-tags-${var.environment}"
  resource_group_id    = data.azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/9b3b6b3a-1955-4437-9152-8851b50dfeb0"
  display_name         = "Enforce ACR image tag immutability"
  description          = "Prevents container image tags from being overwritten in the ACR, mitigating supply-chain attacks."

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })
}

###############################################################################
# ACR Private Endpoint
###############################################################################
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.acr_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-group"
    private_dns_zone_ids = [var.acr_private_dns_zone_id]
  }
}

###############################################################################
# RBAC — Web + API Apps pull from ACR
###############################################################################
resource "azurerm_role_assignment" "acr_pull_web" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.web_app_principal_id
}

resource "azurerm_role_assignment" "acr_pull_api" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.api_app_principal_id
}

###############################################################################
# RBAC — Storage Blob Data Reader for Web + API (product images)
###############################################################################
resource "azurerm_role_assignment" "storage_reader_web" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.web_app_principal_id
}

resource "azurerm_role_assignment" "storage_reader_api" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.api_app_principal_id
}

###############################################################################
# Diagnostic Settings — Key Vault
###############################################################################
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-kv-${var.environment}"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }
  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

###############################################################################
# Diagnostic Settings — ACR
###############################################################################
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr-${var.environment}"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }
  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
