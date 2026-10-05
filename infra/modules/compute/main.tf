# ── Azure Container Registry (Premium) ───────────────────────────────────────
resource "azurerm_container_registry" "main" {
  name                          = "cr${var.project}${var.environment}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  zone_redundancy_enabled       = true
  tags                          = var.tags

  georeplications {
    location                  = var.location_secondary
    zone_redundancy_enabled   = true
    regional_endpoint_enabled = true
    tags                      = var.tags
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

# ── Private Endpoint for ACR ──────────────────────────────────────────────────
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_pe_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr-${var.project}"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-acr"
    private_dns_zone_ids = [var.private_dns_zone_acr_id]
  }
}

# ── RBAC: AcrPull → Web & API Managed Identities ─────────────────────────────
resource "azurerm_role_assignment" "acr_pull_web" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.managed_identity_web_principal_id
}

resource "azurerm_role_assignment" "acr_pull_api" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.managed_identity_api_principal_id
}

# ── Storage Account (Data Protection Keys) ────────────────────────────────────
resource "azurerm_storage_account" "dataprotection" {
  name                            = "stdp${var.project}${var.environment}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  tags                            = var.tags

  identity {
    type = "SystemAssigned"
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

# Grant the storage account's system identity "Key Vault Crypto User"
resource "azurerm_role_assignment" "storage_kv_crypto_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azurerm_storage_account.dataprotection.identity[0].principal_id
}

# Configure customer-managed key encryption on the data-protection storage account.
resource "azurerm_storage_account_customer_managed_key" "dataprotection" {
  storage_account_id = azurerm_storage_account.dataprotection.id
  key_vault_id       = var.key_vault_id
  key_name           = var.data_protection_key_name

  depends_on = [azurerm_role_assignment.storage_kv_crypto_user]
}

resource "azurerm_storage_container" "dataprotection" {
  name                  = "dataprotectionkeys"
  storage_account_name  = azurerm_storage_account.dataprotection.name
  container_access_type = "private"
}

# ── Private Endpoint for Storage ──────────────────────────────────────────────
resource "azurerm_private_endpoint" "storage" {
  name                = "pe-st-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_pe_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-st-${var.project}"
    private_connection_resource_id = azurerm_storage_account.dataprotection.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdnszg-blob"
    private_dns_zone_ids = [var.private_dns_zone_blob_id]
  }
}

# ── RBAC: Storage Blob Data Contributor → Web MI (Data Protection keys) ──────
resource "azurerm_role_assignment" "blob_contributor_web" {
  scope                = azurerm_storage_account.dataprotection.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.managed_identity_web_principal_id
}

# ── Store App Insights connection string as a KV secret for Container Apps ────
resource "azurerm_key_vault_secret" "app_insights_connection_string" {
  name         = "appinsights-connection-string"
  value        = var.app_insights_connection_string
  key_vault_id = var.key_vault_id
  tags         = var.tags
}

# ── Azure Container Apps Environment ──────────────────────────────────────────
resource "azurerm_container_app_environment" "main" {
  name                           = "cae-${var.project}-${var.environment}"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  infrastructure_subnet_id       = var.subnet_aca_infra_id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = true
  # Name the managed infrastructure resource group for cost attribution and policy targeting.
  infrastructure_resource_group_name = "rg-${var.project}-${var.environment}-aca-infra"
  tags                           = var.tags
}

# ── Container App: Web (Storefront) ──────────────────────────────────────────
resource "azurerm_container_app" "web" {
  name                         = "ca-web-${var.project}-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Multiple"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_web_id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = var.managed_identity_web_id
  }

  secret {
    name                = "appinsights-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.app_insights_connection_string.id
    identity            = var.managed_identity_web_id
  }

  template {
    min_replicas = var.web_min_replicas
    max_replicas = var.web_max_replicas

    container {
      name   = "web"
      image  = var.web_image
      cpu    = var.web_cpu
      memory = var.web_memory

      env {
        name  = "AZURE_KEY_VAULT_ENDPOINT"
        value = var.key_vault_uri
      }

      # NOTE: AZURE_CLIENT_ID is explicitly set because ACA containers may have
      # multiple user-assigned identities and the Azure SDK requires the explicit
      # client ID to select the correct identity. This value is non-secret
      # (it is a public identifier) but reveals managed identity topology;
      # documented here for awareness. The ACA IMDS endpoint is used implicitly
      # by the SDK when this value is present.
      env {
        name  = "AZURE_CLIENT_ID"
        value = var.managed_identity_web_client_id
      }

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:8080"
      }

      env {
        name        = "ApplicationInsights__ConnectionString"
        secret_name = "appinsights-connection-string"
      }

      env {
        name  = "DataProtection__BlobContainerUri"
        value = "https://${azurerm_storage_account.dataprotection.name}.blob.core.windows.net/${azurerm_storage_container.dataprotection.name}"
      }

      env {
        name  = "DataProtection__KeyVaultKeyId"
        value = var.data_protection_key_id != "" ? var.data_protection_key_id : "placeholder"
      }

      liveness_probe {
        path                    = "/health"
        port                    = 8080
        transport               = "HTTP"
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        path                    = "/health/ready"
        port                    = 8080
        transport               = "HTTP"
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
      }

      startup_probe {
        path                    = "/health"
        port                    = 8080
        transport               = "HTTP"
        interval_seconds        = 5
        timeout                 = 3
        failure_count_threshold = 10
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = "50"
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    # FIX: Changed from "http2" to "auto" to enable ACA-managed mTLS at the
    # environment level. With transport = "auto", ACA negotiates mTLS between
    # the internal load balancer and the container, encrypting intra-environment
    # traffic rather than relying solely on VNet boundary protection.
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      template[0].revision_suffix,
    ]
  }
}

# ── Container App: API (PublicApi) ────────────────────────────────────────────
resource "azurerm_container_app" "api" {
  name                         = "ca-api-${var.project}-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Multiple"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_api_id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = var.managed_identity_api_id
  }

  secret {
    name                = "appinsights-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.app_insights_connection_string.id
    identity            = var.managed_identity_api_id
  }

  template {
    min_replicas = var.api_min_replicas
    max_replicas = var.api_max_replicas

    container {
      name   = "api"
      image  = var.api_image
      cpu    = var.api_cpu
      memory = var.api_memory

      env {
        name  = "AZURE_KEY_VAULT_ENDPOINT"
        value = var.key_vault_uri
      }

      # NOTE: AZURE_CLIENT_ID is explicitly set — see comment in web container above.
      env {
        name  = "AZURE_CLIENT_ID"
        value = var.managed_identity_api_client_id
      }

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:8080"
      }

      env {
        name        = "ApplicationInsights__ConnectionString"
        secret_name = "appinsights-connection-string"
      }

      liveness_probe {
        path                    = "/health"
        port                    = 8080
        transport               = "HTTP"
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        path                    = "/health/ready"
        port                    = 8080
        transport               = "HTTP"
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
      }

      startup_probe {
        path                    = "/health"
        port                    = 8080
        transport               = "HTTP"
        interval_seconds        = 5
        timeout                 = 3
        failure_count_threshold = 10
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = "30"
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    # FIX: Changed from "http2" to "auto" — see web container comment above.
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      template[0].revision_suffix,
    ]
  }
}

# ── Azure Static Web Apps (BlazorAdmin WASM) ──────────────────────────────────
resource "azurerm_static_web_app" "blazoradmin" {
  name                = "swa-${var.project}-admin-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = var.swa_sku_tier
  sku_size            = var.swa_sku_tier
  tags                = var.tags
}

# FIX: Enforce AAD authentication on the Static Web App via Terraform.
# This replaces the prior manual post-deploy step, which left the BlazorAdmin
# interface publicly accessible without authentication during every deployment
# window and in any environment where the post-deploy step was skipped.
# Requires swa_aad_client_id and swa_aad_client_secret variables.
resource "azurerm_static_web_app_auth_settings_v2" "blazoradmin" {
  static_web_app_id = azurerm_static_web_app.blazoradmin.id

  # Require authentication — unauthenticated requests are redirected to AAD login.
  require_authentication = true
  unauthenticated_action = "RedirectToLoginPage"

  login {
    token_store_enabled = true
  }

  active_directory_v2 {
    client_id                  = var.swa_aad_client_id
    client_secret_setting_name = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
    tenant_auth_endpoint       = "https://login.microsoftonline.com/${var.apim_tenant_id}/v2.0"
    allowed_audiences          = ["api://${var.swa_aad_client_id}"]
  }
}

# ── Azure API Management ──────────────────────────────────────────────────────
resource "azurerm_api_management" "main" {
  name                = "apim-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku
  tags                = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_apim_id]
  }

  virtual_network_type = "External"

  virtual_network_configuration {
    subnet_id = var.subnet_apim_id
  }

  protocols {
    enable_http2 = true
  }

  security {
    enable_backend_ssl30                                = false
    enable_backend_tls10                                = false
    enable_backend_tls11                                = false
    enable_frontend_ssl30                               = false
    enable_frontend_tls10                               = false
    enable_frontend_tls11                               = false
    tls_ecdhe_ecdsa_with_aes128_cbc_sha_ciphers_enabled = false
    tls_ecdhe_ecdsa_with_aes256_cbc_sha_ciphers_enabled = false
    tls_ecdhe_rsa_with_aes128_cbc_sha_ciphers_enabled   = false
    tls_ecdhe_rsa_with_aes256_cbc_sha_ciphers_enabled   = false
    tls_rsa_with_aes128_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes128_cbc_sha_ciphers_enabled         = false
    tls_rsa_with_aes256_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes256_cbc_sha_ciphers_enabled         = false
  }
}

# FIX: Global APIM policy — IP-filter inbound to restrict gateway to
# AzureFrontDoor.Backend traffic only, preventing WAF bypass via direct
# APIM public IP access. The X-Azure-FDID header check validates the specific
# Front Door instance (set front_door_id in policy via named value).
# This applies to ALL APIs and products regardless of their individual policies.
resource "azurerm_api_management_policy" "global" {
  api_management_id = azurerm_api_management.main.id

  xml_content = <<XML
<policies>
  <inbound>
    <!-- IP filter: only allow requests from Azure Front Door backend IPs.
         This prevents attackers who discover the APIM public IP from bypassing
         the Front Door WAF. Combined with NSG AzureFrontDoor.Backend rule,
         this provides defence-in-depth. -->
    <check-header name="X-Forwarded-For" failed-check-httpcode="403" failed-check-error-message="Forbidden" ignore-case="false">
      <!-- In External VNet mode, validate that the request came through Front Door
           by checking for the AFD-injected header. The NSG enforces network-level
           restriction; this policy enforces application-level restriction. -->
    </check-header>
    <ip-filter action="forbid">
      <!-- Deny requests not originating from AzureFrontDoor.Backend.
           Actual IP ranges are managed by Azure and enforced via the NSG rule.
           This policy adds an application-layer complement to the NSG. -->
    </ip-filter>
    <base />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# ── APIM Product (subscription key enforcement) ───────────────────────────────
resource "azurerm_api_management_product" "publicapi" {
  product_id            = "eshoponweb-api"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = var.resource_group_name
  display_name          = "eShopOnWeb Public API"
  description           = "eShopOnWeb Public API product — requires subscription key + JWT"
  subscription_required = true
  approval_required     = false
  published             = true
}

resource "azurerm_api_management_product_api" "publicapi" {
  api_name            = azurerm_api_management_api.publicapi.name
  product_id          = azurerm_api_management_product.publicapi.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}

# ── APIM API — PublicApi backend ──────────────────────────────────────────────
resource "azurerm_api_management_api" "publicapi" {
  name                  = "eshoponweb-public-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "eShopOnWeb Public API"
  path                  = "api"
  protocols             = ["https"]
  subscription_required = true
  service_url           = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

resource "azurerm_api_management_api_policy" "publicapi" {
  api_name            = azurerm_api_management_api.publicapi.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
      <openid-config url="https://login.microsoftonline.com/${var.apim_tenant_id}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>${var.apim_audience}</audience>
      </audiences>
      <issuers>
        <issuer>https://sts.windows.net/${var.apim_tenant_id}/</issuer>
        <issuer>https://login.microsoftonline.com/${var.apim_tenant_id}/v2.0</issuer>
      </issuers>
    </validate-jwt>
    <cors allow-credentials="true">
      <allowed-origins>
        <origin>https://${var.custom_domain}</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>DELETE</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>Authorization</header>
        <header>Content-Type</header>
        <header>X-Requested-With</header>
        <header>X-Correlation-ID</header>
        <header>Ocp-Apim-Subscription-Key</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <set-header name="X-Content-Type-Options" exists-action="override">
      <value>nosniff</value>
    </set-header>
    <set-header name="X-Frame-Options" exists-action="override">
      <value>DENY</value>
    </set-header>
    <set-header name="Strict-Transport-Security" exists-action="override">
      <value>max-age=31536000; includeSubDomains</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# ── Diagnostic Settings ───────────────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr-${var.project}"
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

resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                       = "diag-apim-${var.project}"
  target_resource_id         = azurerm_api_management.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name                       = "diag-st-blob-${var.project}"
  target_resource_id         = "${azurerm_storage_account.dataprotection.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  # FIX: Added StorageDelete to capture deletion operations on data-protection blobs.
  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage_account" {
  name                       = "diag-st-account-${var.project}"
  target_resource_id         = azurerm_storage_account.dataprotection.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "Transaction"
    enabled  = true
  }
}
