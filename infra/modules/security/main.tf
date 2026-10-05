# ── User-Assigned Managed Identities ─────────────────────────────────────────
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

# Dedicated managed identity for APIM — separate from the API Container App identity.
resource "azurerm_user_assigned_identity" "apim" {
  name                = "id-${var.project}-apim-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "acr_pull" {
  name                = "id-${var.project}-acrpull-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ── Azure Key Vault (Premium SKU, RBAC model, private endpoint) ───────────────
resource "azurerm_key_vault" "main" {
  name                          = "kv-${var.project}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "premium"
  enable_rbac_authorization     = true
  soft_delete_retention_days    = 90
  purge_protection_enabled      = true
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = []
  }

  tags = var.tags

  # FIX: Prevent accidental destruction of Key Vault.
  # With purge_protection_enabled = true and soft_delete_retention_days = 90,
  # destroying and recreating the KV with the same name is blocked for 90 days.
  # Accidental destroy would make all secrets, keys, and CMK-encrypted data
  # inaccessible for 90 days.
  lifecycle {
    prevent_destroy = true
  }
}

# ── Private Endpoint for Key Vault ────────────────────────────────────────────
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_pe_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv-${var.project}"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-kv"
    private_dns_zone_ids = [var.private_dns_zone_keyvault_id]
  }
}

# ── RBAC: Key Vault Secrets Officer → Terraform deployer ─────────────────────
resource "azurerm_role_assignment" "kv_secrets_officer_deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.current_object_id
}

resource "azurerm_role_assignment" "kv_crypto_officer_deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = var.current_object_id
}

# ── RBAC: Key Vault Secrets User → Web Managed Identity ──────────────────────
resource "azurerm_role_assignment" "kv_secrets_web" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.web.principal_id
}

# ── RBAC: Key Vault Secrets User → API Managed Identity ──────────────────────
resource "azurerm_role_assignment" "kv_secrets_api" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# ── RBAC: Key Vault Secrets User → APIM Managed Identity ─────────────────────
resource "azurerm_role_assignment" "kv_secrets_apim" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.apim.principal_id
}

# ── RBAC: Key Vault Crypto User → Web MI (for Data Protection key operations) ──
resource "azurerm_role_assignment" "kv_crypto_web" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azurerm_user_assigned_identity.web.principal_id
}

# ── Key Vault Secrets ─────────────────────────────────────────────────────────
resource "azurerm_key_vault_secret" "jwt_secret_key" {
  name         = "jwt-secret-key"
  value        = random_password.jwt_secret.result
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [
    azurerm_role_assignment.kv_secrets_officer_deployer,
    azurerm_private_endpoint.keyvault,
  ]
}

resource "random_password" "jwt_secret" {
  length           = 64
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
}

# ── Key Vault Key (Data Protection key encryption) ────────────────────────────
resource "azurerm_key_vault_key" "data_protection" {
  name         = "data-protection-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 4096
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P365D"
    notify_before_expiry = "P30D"
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.kv_crypto_officer_deployer,
    azurerm_private_endpoint.keyvault,
  ]
}

# ── Audit Storage Account (immutable SQL audit logs) ─────────────────────────
resource "azurerm_storage_account" "audit" {
  name                            = "staudit${var.project}${var.environment}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  tags                            = var.tags

  identity {
    type = "SystemAssigned"
  }

  blob_properties {
    versioning_enabled = true
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

# Grant the audit storage account's system identity Key Vault Crypto User
resource "azurerm_role_assignment" "audit_storage_kv_crypto_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azurerm_storage_account.audit.identity[0].principal_id
}

# Configure CMK on the audit storage account.
resource "azurerm_storage_account_customer_managed_key" "audit" {
  storage_account_id = azurerm_storage_account.audit.id
  key_vault_id       = azurerm_key_vault.main.id
  key_name           = azurerm_key_vault_key.data_protection.name

  depends_on = [azurerm_role_assignment.audit_storage_kv_crypto_user]
}

# ── Private Endpoint for Audit Storage Account ────────────────────────────────
resource "azurerm_private_endpoint" "audit_storage" {
  name                = "pe-staudit-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_pe_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-staudit-${var.project}"
    private_connection_resource_id = azurerm_storage_account.audit.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-staudit-blob"
    private_dns_zone_ids = [var.private_dns_zone_blob_id]
  }
}

# ── Diagnostic Settings for Key Vault ────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "diag-kv-${var.project}"
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

# ── Diagnostic setting for audit storage account blob service ─────────────────
resource "azurerm_monitor_diagnostic_setting" "audit_storage_blob" {
  name                       = "diag-staudit-blob-${var.project}"
  target_resource_id         = "${azurerm_storage_account.audit.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  # FIX: Added StorageDelete — deletion of audit blobs must be logged
  # to detect tampering with the audit trail.
  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ── Diagnostic setting for audit storage account (account level) ──────────────
resource "azurerm_monitor_diagnostic_setting" "audit_storage_account" {
  name                       = "diag-staudit-account-${var.project}"
  target_resource_id         = azurerm_storage_account.audit.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "Transaction"
    enabled  = true
  }
}
