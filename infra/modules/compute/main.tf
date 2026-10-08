# ===========================================================================
# Compute Module
# Provisions: Azure Container Registry (Premium), Container Apps Environment
#             (mTLS enabled), Container Apps (Web + API), Azure Static Web Apps,
#             Private Endpoint for ACR, Log Analytics linkage
# ===========================================================================

locals {
  prefix = "${var.project}-${var.environment}"
  # ACR names must be alphanumeric, 5-50 chars
  acr_name = "cr${replace(var.project, "-", "")}${var.environment}"
}

# ---------------------------------------------------------------------------
# Azure Container Registry — Premium
# NOTE: geo-replication is not supported as a separate resource in this
# provider version. To enable geo-replication, upgrade to azurerm ~> 4.x
# which supports inline georeplications blocks, or use az cli post-deploy.
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  name                          = local.acr_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  zone_redundancy_enabled       = true
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  network_rule_set {
    default_action = "Deny"
  }

  retention_policy {
    enabled = true
    days    = 30
  }

  trust_policy {
    enabled = true
  }
}

# ---------------------------------------------------------------------------
# Private Endpoint — ACR
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr-${local.prefix}"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_acr_id]
  }
}

# ---------------------------------------------------------------------------
# RBAC: ACA managed identities pull images from ACR
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "web_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.web_managed_identity_principal_id
}

resource "azurerm_role_assignment" "api_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.api_managed_identity_principal_id
}

# ---------------------------------------------------------------------------
# Container Apps Environment (internal VNet-injected, mTLS enabled)
# ---------------------------------------------------------------------------
resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.prefix}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
  tags                       = var.tags

  infrastructure_subnet_id       = var.aca_infra_subnet_id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = true

  # Enforce mTLS for all container-to-container communication within the environment.
  mutual_tls_enabled = true

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }

  workload_profile {
    name                  = "dedicated-d4"
    workload_profile_type = "D4"
    minimum_count         = 1
    maximum_count         = 5
  }
}

# ---------------------------------------------------------------------------
# Container App: ca-web (Storefront / MVC)
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "web" {
  name                         = "ca-web-${local.prefix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Multiple"
  tags                         = var.tags

  template {
    min_replicas = var.web_min_replicas
    max_replicas = var.web_max_replicas

    container {
      name   = "web"
      image  = var.web_container_image
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:8080"
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.web_managed_identity_client_id
      }

      env {
        name  = "AZURE_KEY_VAULT_ENDPOINT"
        value = var.key_vault_uri
      }

      env {
        name        = "ConnectionStrings__CatalogConnection"
        secret_name = "catalog-db-connection"
      }

      env {
        name        = "ConnectionStrings__IdentityConnection"
        secret_name = "identity-db-connection"
      }

      env {
        name        = "ConnectionStrings__Redis"
        secret_name = "redis-connection"
      }

      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "appinsights-connection"
      }

      liveness_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = 8080
        initial_delay           = 15
        interval_seconds        = 30
        failure_count_threshold = 3
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/health/ready"
        port                    = 8080
        interval_seconds        = 10
        failure_count_threshold = 3
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = "50"
    }
  }

  secret {
    name  = "catalog-db-connection"
    value = var.catalog_db_connection_secret
  }

  secret {
    name  = "identity-db-connection"
    value = var.identity_db_connection_secret
  }

  secret {
    name  = "redis-connection"
    value = var.redis_connection_string_secret
  }

  secret {
    name  = "appinsights-connection"
    value = var.app_insights_connection_string
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    # "auto" allows the environment-level mTLS to negotiate correctly.
    transport = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.web_managed_identity_id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = var.web_managed_identity_id
  }

  lifecycle {
    ignore_changes = [
      # Image is managed by CI/CD pipeline; ignore drift on this attribute only.
      template[0].container[0].image,
    ]
  }
}

# ---------------------------------------------------------------------------
# Container App: ca-api (PublicApi)
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "api" {
  name                         = "ca-api-${local.prefix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Multiple"
  tags                         = var.tags

  template {
    min_replicas = var.api_min_replicas
    max_replicas = var.api_max_replicas

    container {
      name   = "api"
      image  = var.api_container_image
      cpu    = 0.75
      memory = "1.5Gi"

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:8080"
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.api_managed_identity_client_id
      }

      env {
        name  = "AZURE_KEY_VAULT_ENDPOINT"
        value = var.key_vault_uri
      }

      env {
        name        = "ConnectionStrings__CatalogConnection"
        secret_name = "catalog-db-connection"
      }

      env {
        name        = "ConnectionStrings__IdentityConnection"
        secret_name = "identity-db-connection"
      }

      env {
        name        = "ConnectionStrings__Redis"
        secret_name = "redis-connection"
      }

      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "appinsights-connection"
      }

      env {
        name        = "JwtSecretKey"
        secret_name = "jwt-secret-key"
      }

      liveness_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = 8080
        initial_delay           = 15
        interval_seconds        = 30
        failure_count_threshold = 3
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/health/ready"
        port                    = 8080
        interval_seconds        = 10
        failure_count_threshold = 3
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = "30"
    }
  }

  secret {
    name  = "catalog-db-connection"
    value = var.catalog_db_connection_secret
  }

  secret {
    name  = "identity-db-connection"
    value = var.identity_db_connection_secret
  }

  secret {
    name  = "redis-connection"
    value = var.redis_connection_string_secret
  }

  secret {
    name  = "appinsights-connection"
    value = var.app_insights_connection_string
  }

  secret {
    name  = "jwt-secret-key"
    value = var.jwt_secret_key_value
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    # "auto" allows the environment-level mTLS to negotiate correctly.
    transport = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.api_managed_identity_id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = var.api_managed_identity_id
  }

  lifecycle {
    ignore_changes = [
      # Image is managed by CI/CD pipeline; ignore drift on this attribute only.
      template[0].container[0].image,
    ]
  }
}

# ---------------------------------------------------------------------------
# Azure Static Web Apps — BlazorAdmin WASM
# ---------------------------------------------------------------------------
resource "azurerm_static_web_app" "blazor_admin" {
  name                = "swa-${var.project}-blazoradmin-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = var.swa_sku_tier
  sku_size            = var.swa_sku_tier
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Diagnostic Settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr-${local.prefix}"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
