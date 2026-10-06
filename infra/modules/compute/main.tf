###############################################################################
# Storage Account (product images + Data Protection keys)
###############################################################################
resource "azurerm_storage_account" "images" {
  name                            = "st${var.project}${var.environment}images"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_account_replication_type
  min_tls_version                 = "TLS1_2"
  # Disable anonymous public blob access — images served via managed identity
  allow_nested_items_to_be_public = false
  # Disable shared key access — use Entra ID / managed identity only
  shared_access_key_enabled       = false
  tags                            = var.tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }
}

# Product images container — private; access via managed identity only
resource "azurerm_storage_container" "product_images" {
  name                  = "product-images"
  storage_account_name  = azurerm_storage_account.images.name
  container_access_type = "private"
}

###############################################################################
# Diagnostic Setting — Storage Account (account-level)
###############################################################################
resource "azurerm_monitor_diagnostic_setting" "storage_account" {
  name                       = "diag-st-images-${var.environment}"
  target_resource_id         = "${azurerm_storage_account.images.id}/blobServices/default"
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

###############################################################################
# App Service Plan — Web Frontend (P2v3, Zone-Redundant)
###############################################################################
resource "azurerm_service_plan" "web" {
  name                         = "asp-${var.project}-web-${var.environment}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  os_type                      = "Linux"
  sku_name                     = var.web_app_sku_name
  zone_balancing_enabled       = true
  tags                         = var.tags
}

###############################################################################
# App Service — Web MVC + BlazorAdmin
###############################################################################
resource "azurerm_linux_web_app" "web" {
  name                      = "app-${var.project}-web-${var.environment}"
  resource_group_name       = var.resource_group_name
  location                  = var.location
  service_plan_id           = azurerm_service_plan.web.id
  virtual_network_subnet_id = var.web_subnet_id
  https_only                = true
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
    vnet_route_all_enabled                  = true

    application_stack {
      dotnet_version = var.dotnet_version
    }
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT                      = "Production"
    AZURE_KEY_VAULT_ENDPOINT                    = var.key_vault_uri
    AZURE_SQL_CATALOG_CONNECTION_STRING_KEY     = "AZURE-SQL-CATALOG-CONNECTION-STRING"
    AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY    = "AZURE-SQL-IDENTITY-CONNECTION-STRING"
    REDIS_CONNECTION_STRING_KEY                 = "AZURE-REDIS-CONNECTION-STRING"
    APPLICATIONINSIGHTS_CONNECTION_STRING_KEY   = "AZURE-APPINSIGHTS-CONNECTION-STRING"
    JWT_SECRET_KEY_NAME                         = "JWT-SECRET-KEY"
    WEBSITE_VNET_ROUTE_ALL                      = "1"
    WEBSITE_RUN_FROM_PACKAGE                    = "1"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE         = "false"
    STORAGE_ACCOUNT_NAME                        = azurerm_storage_account.images.name
    PRODUCT_IMAGES_CONTAINER                    = azurerm_storage_container.product_images.name
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    application_logs {
      file_system_level = "Warning"
    }
    detailed_error_messages = true
    failed_request_tracing  = true
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

###############################################################################
# Web App Deployment Slot — staging
###############################################################################
resource "azurerm_linux_web_app_slot" "web_staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.web.id
  tags           = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                         = true
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    minimum_tls_version               = "1.2"
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5
    vnet_route_all_enabled            = true

    application_stack {
      dotnet_version = var.dotnet_version
    }
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT                   = "Staging"
    AZURE_KEY_VAULT_ENDPOINT                 = var.key_vault_uri
    AZURE_SQL_CATALOG_CONNECTION_STRING_KEY  = "AZURE-SQL-CATALOG-CONNECTION-STRING"
    AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY = "AZURE-SQL-IDENTITY-CONNECTION-STRING"
    REDIS_CONNECTION_STRING_KEY              = "AZURE-REDIS-CONNECTION-STRING"
    APPLICATIONINSIGHTS_CONNECTION_STRING_KEY = "AZURE-APPINSIGHTS-CONNECTION-STRING"
    JWT_SECRET_KEY_NAME                      = "JWT-SECRET-KEY"
    WEBSITE_VNET_ROUTE_ALL                   = "1"
    WEBSITE_RUN_FROM_PACKAGE                 = "1"
  }
}

###############################################################################
# App Service Plan — Public API (P1v3, Zone-Redundant)
###############################################################################
resource "azurerm_service_plan" "api" {
  name                   = "asp-${var.project}-api-${var.environment}"
  resource_group_name    = var.resource_group_name
  location               = var.location
  os_type                = "Linux"
  sku_name               = var.api_app_sku_name
  zone_balancing_enabled = true
  tags                   = var.tags
}

###############################################################################
# App Service — Public API
###############################################################################
resource "azurerm_linux_web_app" "api" {
  name                      = "app-${var.project}-api-${var.environment}"
  resource_group_name       = var.resource_group_name
  location                  = var.location
  service_plan_id           = azurerm_service_plan.api.id
  virtual_network_subnet_id = var.api_subnet_id
  https_only                = true
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
    vnet_route_all_enabled                  = true

    application_stack {
      dotnet_version = var.dotnet_version
    }
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT                      = "Production"
    AZURE_KEY_VAULT_ENDPOINT                    = var.key_vault_uri
    AZURE_SQL_CATALOG_CONNECTION_STRING_KEY     = "AZURE-SQL-CATALOG-CONNECTION-STRING"
    AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY    = "AZURE-SQL-IDENTITY-CONNECTION-STRING"
    REDIS_CONNECTION_STRING_KEY                 = "AZURE-REDIS-CONNECTION-STRING"
    APPLICATIONINSIGHTS_CONNECTION_STRING_KEY   = "AZURE-APPINSIGHTS-CONNECTION-STRING"
    JWT_SECRET_KEY_NAME                         = "JWT-SECRET-KEY"
    WEBSITE_VNET_ROUTE_ALL                      = "1"
    WEBSITE_RUN_FROM_PACKAGE                    = "1"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE         = "false"
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    application_logs {
      file_system_level = "Warning"
    }
    detailed_error_messages = true
    failed_request_tracing  = true
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

###############################################################################
# API App Deployment Slot — staging
###############################################################################
resource "azurerm_linux_web_app_slot" "api_staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.api.id
  tags           = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                         = true
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    minimum_tls_version               = "1.2"
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5
    vnet_route_all_enabled            = true

    application_stack {
      dotnet_version = var.dotnet_version
    }
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT                    = "Staging"
    AZURE_KEY_VAULT_ENDPOINT                  = var.key_vault_uri
    AZURE_SQL_CATALOG_CONNECTION_STRING_KEY   = "AZURE-SQL-CATALOG-CONNECTION-STRING"
    AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY  = "AZURE-SQL-IDENTITY-CONNECTION-STRING"
    REDIS_CONNECTION_STRING_KEY               = "AZURE-REDIS-CONNECTION-STRING"
    APPLICATIONINSIGHTS_CONNECTION_STRING_KEY = "AZURE-APPINSIGHTS-CONNECTION-STRING"
    JWT_SECRET_KEY_NAME                       = "JWT-SECRET-KEY"
    WEBSITE_VNET_ROUTE_ALL                    = "1"
    WEBSITE_RUN_FROM_PACKAGE                  = "1"
  }
}

###############################################################################
# Autoscale — Web
###############################################################################
resource "azurerm_monitor_autoscale_setting" "web" {
  name                = "autoscale-web-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.web.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = var.web_min_instances
      minimum = var.web_min_instances
      maximum = var.web_max_instances
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
        time_window        = "PT15M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
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
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
      # Notify ops team on every scale event
      custom_emails                         = [var.alert_action_group_email]
    }
  }
}

###############################################################################
# Autoscale — API
###############################################################################
resource "azurerm_monitor_autoscale_setting" "api" {
  name                = "autoscale-api-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.api.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = var.api_min_instances
      minimum = var.api_min_instances
      maximum = var.api_max_instances
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
        threshold          = 65
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
        time_window        = "PT15M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
      # Notify ops team on every scale event
      custom_emails                         = [var.alert_action_group_email]
    }
  }
}

###############################################################################
# Diagnostic settings for App Services
###############################################################################
resource "azurerm_monitor_diagnostic_setting" "web_app" {
  name                       = "diag-web-app-${var.environment}"
  target_resource_id         = azurerm_linux_web_app.web.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }
  enabled_log {
    category = "AppServiceConsoleLogs"
  }
  enabled_log {
    category = "AppServiceAppLogs"
  }
  enabled_log {
    category = "AppServiceAuditLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "api_app" {
  name                       = "diag-api-app-${var.environment}"
  target_resource_id         = azurerm_linux_web_app.api.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }
  enabled_log {
    category = "AppServiceConsoleLogs"
  }
  enabled_log {
    category = "AppServiceAppLogs"
  }
  enabled_log {
    category = "AppServiceAuditLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
