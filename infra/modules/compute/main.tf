data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Azure Container Registry (Premium, geo-replicated)
# trust_policy enabled: only signed images may be pulled.
# ---------------------------------------------------------------------------
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
    days    = 7
    enabled = true
  }

  trust_policy {
    enabled = true
  }
}

# ---------------------------------------------------------------------------
# ACR Geo-Replication to secondary region (zone-redundant)
# ---------------------------------------------------------------------------
resource "azurerm_container_registry_replication" "secondary" {
  container_registry_name = azurerm_container_registry.main.name
  resource_group_name     = var.resource_group_name
  location                = var.secondary_location
  zone_redundancy_enabled = true
  tags                    = var.tags
}

# ---------------------------------------------------------------------------
# Private Endpoint — ACR
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "dns-acr"
    private_dns_zone_ids = [
      "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
    ]
  }
}

# ---------------------------------------------------------------------------
# RBAC — AcrPull for Managed Identity
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "acr_pull_mi" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.managed_identity_principal_id
}

# ---------------------------------------------------------------------------
# ACR Diagnostic Settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr-${var.project}-${var.environment}"
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

# ---------------------------------------------------------------------------
# Container Apps Environment (VNet-injected, internal LB, zone-redundant)
# ---------------------------------------------------------------------------
resource "azurerm_container_app_environment" "main" {
  name                           = "cae-${var.project}-${var.environment}"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  infrastructure_subnet_id       = var.aca_infra_subnet_id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = true
  tags                           = var.tags
}

# ---------------------------------------------------------------------------
# Container App — Web (MVC Storefront)
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "web" {
  name                         = "ca-web-${var.project}-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Multiple"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = var.managed_identity_id
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    transport        = "http2"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.web_min_replicas
    max_replicas = var.web_max_replicas

    container {
      name   = "web"
      image  = var.web_image
      cpu    = 1.0
      memory = "2Gi"

      env {
        name        = "ConnectionStrings__CatalogConnection"
        secret_name = "catalog-db-connection-string"
      }

      env {
        name        = "ConnectionStrings__IdentityConnection"
        secret_name = "identity-db-connection-string"
      }

      env {
        name        = "ConnectionStrings__Redis"
        secret_name = "redis-connection-string"
      }

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = var.app_insights_connection_string
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.managed_identity_client_id
      }

      env {
        name  = "KeyVaultUri"
        value = var.key_vault_uri
      }

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ASPNETCORE_HTTP_PORTS"
        value = "8080"
      }

      liveness_probe {
        path                    = "/health/live"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 30
        interval_seconds        = 10
        failure_count_threshold = 3
      }

      readiness_probe {
        path                    = "/health/ready"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 5
        interval_seconds        = 5
        failure_count_threshold = 3
      }

      startup_probe {
        path                    = "/health/live"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 10
        interval_seconds        = 5
        failure_count_threshold = 10
      }
    }

    custom_scale_rule {
      name             = "http-scale-rule"
      custom_rule_type = "http"
      metadata = {
        concurrentRequests = "100"
      }
    }

    custom_scale_rule {
      name             = "cpu-scale-rule"
      custom_rule_type = "cpu"
      metadata = {
        type  = "Utilization"
        value = "70"
      }
    }
  }

  secret {
    name                = "catalog-db-connection-string"
    key_vault_secret_id = "${var.key_vault_uri}secrets/${var.catalog_sql_connection_kv_secret_name}"
    identity            = var.managed_identity_id
  }

  secret {
    name                = "identity-db-connection-string"
    key_vault_secret_id = "${var.key_vault_uri}secrets/${var.identity_sql_connection_kv_secret_name}"
    identity            = var.managed_identity_id
  }

  secret {
    name                = "redis-connection-string"
    key_vault_secret_id = "${var.key_vault_uri}secrets/${var.redis_connection_kv_secret_name}"
    identity            = var.managed_identity_id
  }

  depends_on = [
    azurerm_role_assignment.acr_pull_mi,
    azurerm_container_app_environment.main,
  ]
}

# ---------------------------------------------------------------------------
# Container App — Public API
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "api" {
  name                         = "ca-api-${var.project}-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Multiple"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = var.managed_identity_id
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    transport        = "http2"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.api_min_replicas
    max_replicas = var.api_max_replicas

    container {
      name   = "publicapi"
      image  = var.api_image
      cpu    = 0.75
      memory = "1.5Gi"

      env {
        name        = "ConnectionStrings__CatalogConnection"
        secret_name = "catalog-db-connection-string"
      }

      env {
        name        = "ConnectionStrings__Redis"
        secret_name = "redis-connection-string"
      }

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = var.app_insights_connection_string
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.managed_identity_client_id
      }

      env {
        name  = "KeyVaultUri"
        value = var.key_vault_uri
      }

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ASPNETCORE_HTTP_PORTS"
        value = "8080"
      }

      liveness_probe {
        path                    = "/health/live"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 30
        interval_seconds        = 10
        failure_count_threshold = 3
      }

      readiness_probe {
        path                    = "/health/ready"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 5
        interval_seconds        = 5
        failure_count_threshold = 3
      }

      startup_probe {
        path                    = "/health/live"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 10
        interval_seconds        = 5
        failure_count_threshold = 10
      }
    }

    custom_scale_rule {
      name             = "http-scale-rule"
      custom_rule_type = "http"
      metadata = {
        concurrentRequests = "50"
      }
    }
  }

  secret {
    name                = "catalog-db-connection-string"
    key_vault_secret_id = "${var.key_vault_uri}secrets/${var.catalog_sql_connection_kv_secret_name}"
    identity            = var.managed_identity_id
  }

  secret {
    name                = "redis-connection-string"
    key_vault_secret_id = "${var.key_vault_uri}secrets/${var.redis_connection_kv_secret_name}"
    identity            = var.managed_identity_id
  }

  depends_on = [
    azurerm_role_assignment.acr_pull_mi,
    azurerm_container_app_environment.main,
  ]
}

# ---------------------------------------------------------------------------
# Azure Static Web Apps (BlazorAdmin)
# ---------------------------------------------------------------------------
resource "azurerm_static_web_app" "blazoradmin" {
  name                = "swa-blazoradmin-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = var.swa_sku
  sku_size            = var.swa_sku
  tags                = var.tags
}
