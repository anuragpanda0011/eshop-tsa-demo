data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# User-Assigned Managed Identity
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "main" {
  name                = "id-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
resource "azurerm_key_vault" "main" {
  name                          = "kv-${var.project}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = var.kv_sku
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = []
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Key Vault Diagnostic Settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-kv-${var.project}-${var.environment}"
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

# ---------------------------------------------------------------------------
# RBAC — Key Vault Secrets Officer for Terraform deployer
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "kv_secrets_officer_deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------------------------------------------------------------------------
# RBAC — Key Vault Secrets User for Managed Identity
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "kv_secrets_user_mi" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# ---------------------------------------------------------------------------
# Bootstrap secrets (SQL credentials)
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "sql_admin_login" {
  name         = "sql-admin-login"
  value        = var.sql_admin_login
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.kv_secrets_officer_deployer]
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.kv_secrets_officer_deployer]
}

# ---------------------------------------------------------------------------
# Private Endpoint — Key Vault
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv-${var.project}-${var.environment}"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-kv"
    private_dns_zone_ids = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"]
  }
}

# ---------------------------------------------------------------------------
# Azure Front Door Standard Profile
# ---------------------------------------------------------------------------
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "afd-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Front Door Endpoint
# ---------------------------------------------------------------------------
resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "ep-${var.project}-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  tags                     = var.tags
}

# ---------------------------------------------------------------------------
# WAF Policy
# WAF is in Prevention mode with:
#   - Microsoft DefaultRuleSet 2.1 (OWASP equivalent)
#   - BotManagerRuleSet 1.0
#   - Global rate-limit: 150 req/min per IP (was 1,000 and broken)
#   - Sensitive-path rate-limit: 30 req/min per IP
# ---------------------------------------------------------------------------
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                              = "waf${var.project}${var.environment}"
  resource_group_name               = var.resource_group_name
  sku_name                          = azurerm_cdn_frontdoor_profile.main.sku_name
  enabled                           = true
  mode                              = "Prevention"
  redirect_url                      = null
  custom_block_response_status_code = 403
  tags                              = var.tags

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }

  # Global rate-limit: 150 req/min per IP
  # match_values = ["0.0.0.0/0"] with negation_condition = false → matches ALL IPs
  custom_rule {
    name                           = "RateLimitPerIP"
    enabled                        = true
    priority                       = 100
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 150
    type                           = "RateLimitRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["0.0.0.0/0"]
    }
  }

  # Stricter rate-limit on sensitive paths: 30 req/min per IP
  custom_rule {
    name                           = "RateLimitSensitivePaths"
    enabled                        = true
    priority                       = 90
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 30
    type                           = "RateLimitRule"
    action                         = "Block"

    match_condition {
      match_variable = "RequestUri"
      operator       = "Contains"
      match_values   = ["/account", "/basket", "/api/"]
    }

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["0.0.0.0/0"]
    }
  }
}

# ---------------------------------------------------------------------------
# Front Door Security Policy (WAF attachment)
# ---------------------------------------------------------------------------
resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "sp-${var.project}-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  firewall {
    cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main.id

    association {
      domain {
        cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main.id
      }
      patterns_to_match = ["/*"]
    }
  }
}

# ---------------------------------------------------------------------------
# Front Door Origin Groups
# ---------------------------------------------------------------------------
resource "azurerm_cdn_frontdoor_origin_group" "web" {
  name                     = "og-web-${var.project}-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    path                = "/health"
    request_type        = "GET"
    protocol            = "Https"
    interval_in_seconds = 30
  }

  session_affinity_enabled = false
}

resource "azurerm_cdn_frontdoor_origin_group" "api" {
  name                     = "og-api-${var.project}-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    path                = "/health"
    request_type        = "GET"
    protocol            = "Https"
    interval_in_seconds = 30
  }

  session_affinity_enabled = false
}

resource "azurerm_cdn_frontdoor_origin_group" "blob" {
  name                     = "og-blob-${var.project}-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 0
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 60
  }

  session_affinity_enabled = false
}

# ---------------------------------------------------------------------------
# Front Door Diagnostic Settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "afd" {
  name                       = "diag-afd-${var.project}-${var.environment}"
  target_resource_id         = azurerm_cdn_frontdoor_profile.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorHealthProbeLog"
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
