# ===========================================================================
# Security Module
# Provisions: User-Assigned Managed Identities, Azure Key Vault (RBAC),
#             Private Endpoint for Key Vault, Storage Account (Data Protection),
#             Role Assignments, OIDC Federated Identity for GitHub Actions,
#             Separate KMS keys for storage CMK and Data Protection ring.
# ===========================================================================

locals {
  prefix = "${var.project}-${var.environment}"
}

data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# User-Assigned Managed Identities
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "web" {
  name                = "id-${var.project}-web-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "api" {
  name                = "id-${var.project}-api-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "cicd" {
  name                = "id-${var.project}-cicd-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Azure Key Vault (RBAC model, private endpoint)
# ---------------------------------------------------------------------------
resource "random_string" "kv_suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_key_vault" "main" {
  name                          = "kv-${var.project}${var.environment}${random_string.kv_suffix.result}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = []
  }
}

# ---------------------------------------------------------------------------
# Private Endpoint for Key Vault
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-kv-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv-${local.prefix}"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "kv-dns-zone-group"
    private_dns_zone_ids = [
      data.azurerm_private_dns_zone.kv.id
    ]
  }
}

data "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

# ---------------------------------------------------------------------------
# Key Vault Keys
#
# Separate keys are created for distinct trust domains:
#   - storage_cmk:      encrypts storage account data at rest (CMK)
#   - data_protection:  used by ASP.NET Core Data Protection ring (signing/encryption)
#
# This limits blast radius: a rotation failure or compromise of one key does
# not affect the other domain.
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_key" "storage_cmk" {
  name         = "key-storage-cmk-${local.prefix}"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 4096
  key_opts     = ["wrapKey", "unwrapKey"]
  tags         = var.tags

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P1Y"
    notify_before_expiry = "P29D"
  }

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

resource "azurerm_key_vault_key" "data_protection" {
  name         = "key-dataprotection-${local.prefix}"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["encrypt", "decrypt", "sign", "verify", "wrapKey", "unwrapKey"]
  tags         = var.tags

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P1Y"
    notify_before_expiry = "P29D"
  }

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# ---------------------------------------------------------------------------
# RBAC Role Assignments — Key Vault
# ---------------------------------------------------------------------------

# Web identity: read secrets
resource "azurerm_role_assignment" "web_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.web.principal_id
}

# API identity: read secrets
resource "azurerm_role_assignment" "api_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# CI/CD identity: manage secrets during deployment
resource "azurerm_role_assignment" "cicd_kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.cicd.principal_id
}

# Terraform deployer: full admin (so initial secrets/keys can be created)
resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Web and API identities need Key Vault Crypto User to use the data protection key
resource "azurerm_role_assignment" "web_kv_crypto_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azurerm_user_assigned_identity.web.principal_id
}

resource "azurerm_role_assignment" "api_kv_crypto_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# ---------------------------------------------------------------------------
# Key Vault Secrets
# ---------------------------------------------------------------------------

# JWT signing key — sourced from the input variable (never hardcoded).
# The CI/CD pipeline should rotate this via az keyvault secret set after
# the initial deployment using the Key Vault Secrets Officer role.
resource "azurerm_key_vault_secret" "jwt_secret_key" {
  name         = "JwtSecretKey"
  value        = var.jwt_secret_key_value
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  # Set expiration to 1 year from initial creation.
  # The CI/CD pipeline must rotate before expiry.
  expiration_date = timeadd(timestamp(), "8760h")

  lifecycle {
    # Prevent Terraform from reverting the expiration date on subsequent applies
    # (it would always change because timestamp() is evaluated at plan time).
    ignore_changes = [expiration_date, value]
  }

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# Data protection storage connection — stores only the blob endpoint URI.
# Applications use DefaultAzureCredential (Managed Identity) for blob access;
# no storage account key is stored or referenced.
resource "azurerm_key_vault_secret" "data_protection_storage_endpoint" {
  name         = "DataProtectionStorageBlobEndpoint"
  value        = azurerm_storage_account.data_protection.primary_blob_endpoint
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  expiration_date = timeadd(timestamp(), "8760h")

  lifecycle {
    ignore_changes = [expiration_date]
  }

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# ---------------------------------------------------------------------------
# Storage Account for ASP.NET Core Data Protection Key Ring
# ---------------------------------------------------------------------------
resource "random_string" "sa_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "data_protection" {
  name                            = "sadp${replace(var.project, "-", "")}${var.environment}${random_string.sa_suffix.result}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  tags                            = var.tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # Customer-managed key encryption using the dedicated storage CMK key.
  # The storage account's system-assigned identity must have Key Vault Crypto
  # Service Encryption User on the key (assigned below).
  identity {
    type = "SystemAssigned"
  }
}

# Grant the storage account identity permission to use the CMK
resource "azurerm_role_assignment" "sa_dp_kv_crypto_encryption" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_storage_account.data_protection.identity[0].principal_id
}

resource "azurerm_storage_account_customer_managed_key" "data_protection" {
  storage_account_id = azurerm_storage_account.data_protection.id
  key_vault_id       = azurerm_key_vault.main.id
  key_name           = azurerm_key_vault_key.storage_cmk.name

  depends_on = [azurerm_role_assignment.sa_dp_kv_crypto_encryption]
}

resource "azurerm_storage_container" "data_protection" {
  name                  = "dataprotection-keys"
  storage_account_name  = azurerm_storage_account.data_protection.name
  container_access_type = "private"
}

# Private endpoint for data protection storage
resource "azurerm_private_endpoint" "storage" {
  name                = "pe-sa-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sa-${local.prefix}"
    private_connection_resource_id = azurerm_storage_account.data_protection.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "sa-dns-zone-group"
    private_dns_zone_ids = [
      data.azurerm_private_dns_zone.blob.id
    ]
  }
}

data "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
}

# RBAC: web and api identities can read/write blobs (data protection keys)
# using Managed Identity — no storage account key required.
resource "azurerm_role_assignment" "web_storage_blob_contributor" {
  scope                = azurerm_storage_account.data_protection.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.web.principal_id
}

resource "azurerm_role_assignment" "api_storage_blob_contributor" {
  scope                = azurerm_storage_account.data_protection.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC Federated Identity Credential
# ---------------------------------------------------------------------------
resource "azuread_application" "cicd" {
  display_name = "sp-${local.prefix}-cicd"
}

resource "azuread_service_principal" "cicd" {
  client_id = azuread_application.cicd.client_id
}

resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.cicd.id
  display_name   = "github-main-branch"
  description    = "GitHub Actions OIDC for main branch deployments"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
}

resource "azuread_application_federated_identity_credential" "github_pr" {
  application_id = azuread_application.cicd.id
  display_name   = "github-pull-requests"
  description    = "GitHub Actions OIDC for pull requests"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

resource "azuread_application_federated_identity_credential" "github_environment" {
  application_id = azuread_application.cicd.id
  display_name   = "github-environment-prod"
  description    = "GitHub Actions OIDC for prod environment"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:environment:production"
}

# ---------------------------------------------------------------------------
# Diagnostic settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-kv-${local.prefix}"
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

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "diag-sa-${local.prefix}"
  target_resource_id         = "${azurerm_storage_account.data_protection.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
