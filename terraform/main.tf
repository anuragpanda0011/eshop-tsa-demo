# ---------------------------------------------------------------------------
# Root main.tf — eShopOnWeb Azure Target-State Architecture
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "platform-team"
  }
}

# ---------------------------------------------------------------------------
# Primary Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------
# Monitoring Module (deployed first — other modules reference workspace ID)
# ---------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = local.name_prefix
  log_retention_days  = var.log_retention_days
  alert_email_address = var.alert_email_address
  tags                = local.common_tags

  web_app_id     = module.compute.web_app_id
  api_app_id     = module.compute.api_app_id
  catalog_sql_id = module.database.catalog_sql_server_id
  redis_id       = module.database.redis_id
  key_vault_id   = module.security.key_vault_id

  depends_on = [
    module.compute,
    module.database,
    module.security,
  ]
}

# ---------------------------------------------------------------------------
# Security / Identity Module
# ---------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = local.name_prefix
  tenant_id           = var.tenant_id
  devops_object_id    = var.devops_object_id
  key_vault_sku       = var.key_vault_sku
  sql_admin_password  = var.sql_admin_password
  subnet_keyvault_id  = module.network.subnet_ids["keyvault"]
  vnet_id             = module.network.vnet_id
  tags                = local.common_tags

  web_app_principal_id = module.compute.web_app_principal_id
  api_app_principal_id = module.compute.api_app_principal_id

  depends_on = [
    module.network,
    module.compute,
  ]
}

# ---------------------------------------------------------------------------
# Network Module
# ---------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  resource_group_name    = azurerm_resource_group.main.name
  location               = var.location
  name_prefix            = local.name_prefix
  vnet_address_space     = var.vnet_address_space
  subnet_cidrs           = var.subnet_cidrs
  dns_zone_name          = var.dns_zone_name
  front_door_sku         = var.front_door_sku
  web_app_hostname       = module.compute.web_app_hostname
  api_app_hostname       = module.compute.api_app_hostname
  ssl_certificate_data   = var.ssl_certificate_data
  ssl_certificate_password = var.ssl_certificate_password
  tags                   = local.common_tags

  depends_on = [
    azurerm_resource_group.main,
    module.compute,
  ]
}

# ---------------------------------------------------------------------------
# Compute Module
# ---------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  resource_group_name   = azurerm_resource_group.main.name
  location              = var.location
  name_prefix           = local.name_prefix
  web_app_sku           = var.web_app_sku
  api_app_sku           = var.api_app_sku
  web_app_min_instances = var.web_app_min_instances
  web_app_max_instances = var.web_app_max_instances
  api_app_min_instances = var.api_app_min_instances
  api_app_max_instances = var.api_app_max_instances
  acr_sku               = var.acr_sku
  docker_image_web      = var.docker_image_web
  docker_image_api      = var.docker_image_api
  docker_image_tag      = var.docker_image_tag
  subnet_apps_id        = module.network.subnet_ids["apps"]
  subnet_api_id         = module.network.subnet_ids["api"]
  subnet_acr_id         = module.network.subnet_ids["acr"]
  appgw_subnet_cidr     = var.subnet_cidrs["appgw"]
  vnet_id               = module.network.vnet_id
  key_vault_uri         = module.security.key_vault_uri
  tags                  = local.common_tags

  depends_on = [
    module.network,
  ]
}

# ---------------------------------------------------------------------------
# Database Module
# ---------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  name_prefix             = local.name_prefix
  sql_admin_login         = var.sql_admin_login
  sql_admin_password      = var.sql_admin_password
  sql_aad_admin_object_id = var.sql_aad_admin_object_id
  catalog_db_sku          = var.catalog_db_sku
  identity_db_sku         = var.identity_db_sku
  redis_sku_name          = var.redis_sku_name
  redis_family            = var.redis_family
  redis_capacity          = var.redis_capacity
  subnet_data_id          = module.network.subnet_ids["data"]
  vnet_id                 = module.network.vnet_id
  log_analytics_id        = module.monitoring.log_analytics_workspace_id
  key_vault_id            = module.security.key_vault_id
  key_vault_key_id        = module.security.data_protection_key_id
  tags                    = local.common_tags

  depends_on = [
    module.network,
    module.monitoring,
    module.security,
  ]
}

# ---------------------------------------------------------------------------
# CI/CD Module
# ---------------------------------------------------------------------------
module "ci_cd" {
  source = "./modules/ci_cd"

  resource_group_name                 = azurerm_resource_group.main.name
  location                            = var.location
  name_prefix                         = local.name_prefix
  github_organization                 = var.github_organization
  github_repository                   = var.github_repository
  environment                         = var.environment
  acr_id                              = module.compute.acr_id
  web_app_id                          = module.compute.web_app_id
  api_app_id                          = module.compute.api_app_id
  key_vault_id                        = module.security.key_vault_id
  user_assigned_identity_id           = module.security.user_assigned_identity_id
  user_assigned_identity_client_id    = module.security.user_assigned_identity_client_id
  user_assigned_identity_principal_id = module.security.user_assigned_identity_principal_id
  subscription_id                     = var.subscription_id
  tenant_id                           = var.tenant_id
  tags                                = local.common_tags

  depends_on = [
    module.security,
    module.compute,
  ]
}
