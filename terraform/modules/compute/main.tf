# ---------------------------------------------------------------------------
# Compute Module — App Service Plans, Web App, API, ACR, Autoscale,
#                  Deployment Slots, VNet Integration, Managed Identity
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Azure Container Registry (Premium — supports private endpoints)
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  name                          = "acr${replace(var.name_prefix, "-", "")}${random_string.acr_suffix.result}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.acr_sku
  admin_enabled                 = false
  public_network_access_enabled = false
  zone_redundancy_enabled       = true
  tags                          = var.tags

  network_rule_set {
    default_action = "Deny"
  }
}

resource "random_string" "acr_suffix" {
  length  = 4
  upper   = false
  special = false

  # Pin the suffix to the deployment name so a taint does not rename the registry.
  keepers = {
    name_prefix = var.name_prefix
  }
}

# Private Endpoint for ACR
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_acr_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr-${var.name_prefix}"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }
}

# ---------------------------------------------------------------------------
# App Service Plan — Web (MVC + Blazor Admin)
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "web" {
  name                   = "asp-web-${var.name_prefix}"
  location               = var.location
  resource_group_name    = var.resource_group_name
  os_type                = "Linux"
  sku_name               = var.web_app_sku
  zone_balancing_enabled = true
  tags                   = var.tags
}

# ---------------------------------------------------------------------------
# App Service Plan — API (Public REST API)
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "api" {
  name                   = "asp-api-${var.name_prefix}"
  location               = var.location
  resource_group_name    = var.resource_group_name
  os_type                = "Linux"
  sku_name               = var.api_app_sku
  zone_balancing_enabled = true
  tags                   = var.tags
}

# ---------------------------------------------------------------------------
# Web App — MVC + Blazor Admin SPA
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app" "web" {
  name                      = "app-web-${var.name_prefix}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  service_plan_id           = azurerm_service_plan.web.id
  https_only                = true
  virtual_network_subnet_id = var.subnet_apps_id
  tags                      = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    ftps_state                              = "Disabled"
    http2_enabled                           = true
    minimum_tls_version                     = "1.2"
    health_check_path                       = "/health"
    health_check_eviction_time_in_min       = 5
    container_registry_use_managed_identity = true
    vnet_route_all_enabled                  = true
    scm_minimum_tls_version                 = "1.2"
    scm_use_main_ip_restriction             = true

    application_stack {
      docker_image_name   = "${var.docker_image_web}:${var.docker_image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
    }

    # Allow only traffic originating from the App Gateway subnet.
    ip_restriction {
      name       = "AllowAppGatewaySubnetOnly"
      action     = "Allow"
      priority   = 100
      ip_address = var.appgw_subnet_cidr
    }

    ip_restriction_default_action = "Deny"
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"   = "false"
    "ASPNETCORE_ENVIRONMENT"                = "Production"
    "KeyVaultUri"                           = var.key_vault_uri
    "ApplicationInsights__ConnectionString" = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/appInsightsConnectionString/)"
    "AZURE_SQL_CATALOG_CONNECTION_STRING"   = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/AZURE-SQL-CATALOG-CONNECTION-STRING/)"
    "AZURE_SQL_IDENTITY_CONNECTION_STRING"  = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/AZURE-SQL-IDENTITY-CONNECTION-STRING/)"
    "REDIS_CONNECTION_STRING"               = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/redisConnectionString/)"
    "DOCKER_REGISTRY_SERVER_URL"            = "https://${azurerm_container_registry.main.login_server}"
  }

  logs {
    http_logs {
      retention_in_days = 30
    }
    application_logs {
      file_system_level = "Warning"
    }
    failed_request_tracing  = true
    detailed_error_messages = true
  }

  lifecycle {
    ignore_changes = [
      site_config[0].application_stack,
    ]
  }
}

# Web App — Staging Deployment Slot
resource "azurerm_linux_web_app_slot" "web_staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.web.id
  https_only     = true
  tags           = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    ftps_state                              = "Disabled"
    http2_enabled                           = true
    minimum_tls_version                     = "1.2"
    health_check_path                       = "/health"
    container_registry_use_managed_identity = true
    vnet_route_all_enabled                  = true
    scm_minimum_tls_version                 = "1.2"
    scm_use_main_ip_restriction             = true

    application_stack {
      docker_image_name   = "${var.docker_image_web}:${var.docker_image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
    }

    # Staging slot — restrict inbound to App Gateway subnet only.
    ip_restriction {
      name       = "AllowAppGatewaySubnetOnly"
      action     = "Allow"
      priority   = 100
      ip_address = var.appgw_subnet_cidr
    }

    ip_restriction_default_action = "Deny"
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"   = "false"
    "ASPNETCORE_ENVIRONMENT"                = "Staging"
    "KeyVaultUri"                           = var.key_vault_uri
    "ApplicationInsights__ConnectionString" = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/appInsightsConnectionString/)"
    "AZURE_SQL_CATALOG_CONNECTION_STRING"   = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/AZURE-SQL-CATALOG-CONNECTION-STRING/)"
    "AZURE_SQL_IDENTITY_CONNECTION_STRING"  = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/AZURE-SQL-IDENTITY-CONNECTION-STRING/)"
    "REDIS_CONNECTION_STRING"               = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/redisConnectionString/)"
  }

  lifecycle {
    ignore_changes = [
      site_config[0].application_stack,
    ]
  }
}

# ---------------------------------------------------------------------------
# API App — Public REST API
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app" "api" {
  name                      = "app-api-${var.name_prefix}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  service_plan_id           = azurerm_service_plan.api.id
  https_only                = true
  virtual_network_subnet_id = var.subnet_api_id
  tags                      = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    ftps_state                              = "Disabled"
    http2_enabled                           = true
    minimum_tls_version                     = "1.2"
    health_check_path                       = "/health"
    health_check_eviction_time_in_min       = 5
    container_registry_use_managed_identity = true
    vnet_route_all_enabled                  = true
    scm_minimum_tls_version                 = "1.2"
    scm_use_main_ip_restriction             = true

    application_stack {
      docker_image_name   = "${var.docker_image_api}:${var.docker_image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
    }

    # Allow only traffic originating from the App Gateway subnet.
    ip_restriction {
      name       = "AllowAppGatewaySubnetOnly"
      action     = "Allow"
      priority   = 100
      ip_address = var.appgw_subnet_cidr
    }

    ip_restriction_default_action = "Deny"
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"   = "false"
    "ASPNETCORE_ENVIRONMENT"                = "Production"
    "KeyVaultUri"                           = var.key_vault_uri
    "ApplicationInsights__ConnectionString" = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/appInsightsConnectionString/)"
    "AZURE_SQL_CATALOG_CONNECTION_STRING"   = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/AZURE-SQL-CATALOG-CONNECTION-STRING/)"
    "JWT_SECRET_KEY"                        = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/JWT-SECRET-KEY/)"
    "REDIS_CONNECTION_STRING"               = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/redisConnectionString/)"
    "DOCKER_REGISTRY_SERVER_URL"            = "https://${azurerm_container_registry.main.login_server}"
  }

  logs {
    http_logs {
      retention_in_days = 30
    }
    application_logs {
      file_system_level = "Warning"
    }
    failed_request_tracing  = true
    detailed_error_messages = true
  }

  lifecycle {
    ignore_changes = [
      site_config[0].application_stack,
    ]
  }
}

# API App — Staging Deployment Slot
resource "azurerm_linux_web_app_slot" "api_staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.api.id
  https_only     = true
  tags           = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    ftps_state                              = "Disabled"
    http2_enabled                           = true
    minimum_tls_version                     = "1.2"
    health_check_path                       = "/health"
    container_registry_use_managed_identity = true
    vnet_route_all_enabled                  = true
    scm_minimum_tls_version                 = "1.2"
    scm_use_main_ip_restriction             = true

    application_stack {
      docker_image_name   = "${var.docker_image_api}:${var.docker_image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
    }

    # Staging slot — restrict inbound to App Gateway subnet only.
    ip_restriction {
      name       = "AllowAppGatewaySubnetOnly"
      action     = "Allow"
      priority   = 100
      ip_address = var.appgw_subnet_cidr
    }

    ip_restriction_default_action = "Deny"
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"   = "false"
    "ASPNETCORE_ENVIRONMENT"                = "Staging"
    "KeyVaultUri"                           = var.key_vault_uri
    "ApplicationInsights__ConnectionString" = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/appInsightsConnectionString/)"
    "AZURE_SQL_CATALOG_CONNECTION_STRING"   = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/AZURE-SQL-CATALOG-CONNECTION-STRING/)"
    "JWT_SECRET_KEY"                        = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/JWT-SECRET-KEY/)"
    "REDIS_CONNECTION_STRING"               = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/redisConnectionString/)"
  }

  lifecycle {
    ignore_changes = [
      site_config[0].application_stack,
    ]
  }
}

# ---------------------------------------------------------------------------
# Autoscale — Web App
# ---------------------------------------------------------------------------
resource "azurerm_monitor_autoscale_setting" "web" {
  name                = "autoscale-web-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.web.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = var.web_app_min_instances
      minimum = var.web_app_min_instances
      maximum = var.web_app_max_instances
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "MemoryPercentage"
        metric_resource_id = azurerm_service_plan.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = false
    }
  }
}

# ---------------------------------------------------------------------------
# Autoscale — API App
# ---------------------------------------------------------------------------
resource "azurerm_monitor_autoscale_setting" "api" {
  name                = "autoscale-api-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.api.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = var.api_app_min_instances
      minimum = var.api_app_min_instances
      maximum = var.api_app_max_instances
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.api.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.api.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = false
    }
  }
}

# ---------------------------------------------------------------------------
# ACR Role Assignments — Allow App Services to pull images
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "web_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.web.identity[0].principal_id
}

resource "azurerm_role_assignment" "api_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
}
