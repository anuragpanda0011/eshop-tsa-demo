# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Monitoring (deployed first — other modules reference workspace/AI IDs)
# ---------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  log_retention_days  = var.log_retention_days
  alert_email         = var.alert_email
  health_probe_token  = var.health_probe_token
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Security / Identity (Key Vault, Managed Identities, RBAC)
# ---------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  project                    = var.project
  environment                = var.environment
  tags                       = var.tags
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id
  vnet_id                    = module.network.vnet_id
  github_org                 = var.github_org
  github_repo                = var.github_repo
  jwt_secret_key_value       = var.jwt_secret_key_value
}

# ---------------------------------------------------------------------------
# Networking (VNet, Subnets, NSGs, Private DNS, Front Door, APIM, Bastion)
# ---------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  project                    = var.project
  environment                = var.environment
  vnet_address_space         = var.vnet_address_space
  tags                       = var.tags
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  custom_domain_name         = var.custom_domain_name
  dns_zone_name              = var.dns_zone_name
  dns_zone_resource_group    = var.dns_zone_resource_group
  apim_publisher_email       = var.apim_publisher_email
}

# ---------------------------------------------------------------------------
# Database (Azure SQL, Private Endpoints for SQL)
# ---------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  project                    = var.project
  environment                = var.environment
  tags                       = var.tags
  sql_admin_login            = var.sql_admin_login
  sql_admin_password         = var.sql_admin_password
  sql_sku_name               = var.sql_sku_name
  sql_max_size_gb            = var.sql_max_size_gb
  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id
  vnet_id                    = module.network.vnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  key_vault_id               = module.security.key_vault_id
  private_dns_zone_sql_id    = module.network.private_dns_zone_sql_id
  private_dns_zone_redis_id  = module.network.private_dns_zone_redis_id
}

# ---------------------------------------------------------------------------
# Compute (ACR, Container Apps Environment, Web CA, API CA, Static Web App)
# ---------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location
  project                         = var.project
  environment                     = var.environment
  tags                            = var.tags
  acr_georeplications             = var.acr_georeplications
  web_container_image             = var.web_container_image
  api_container_image             = var.api_container_image
  web_min_replicas                = var.web_min_replicas
  web_max_replicas                = var.web_max_replicas
  api_min_replicas                = var.api_min_replicas
  api_max_replicas                = var.api_max_replicas
  swa_sku_tier                    = var.swa_sku_tier
  aca_infra_subnet_id             = module.network.aca_infra_subnet_id
  private_endpoint_subnet_id      = module.network.private_endpoint_subnet_id
  vnet_id                         = module.network.vnet_id
  log_analytics_workspace_id      = module.monitoring.log_analytics_workspace_id
  app_insights_connection_string  = module.monitoring.app_insights_connection_string
  key_vault_uri                   = module.security.key_vault_uri
  key_vault_id                    = module.security.key_vault_id
  web_managed_identity_id         = module.security.web_managed_identity_id
  api_managed_identity_id         = module.security.api_managed_identity_id
  web_managed_identity_client_id  = module.security.web_managed_identity_client_id
  api_managed_identity_client_id  = module.security.api_managed_identity_client_id
  web_managed_identity_principal_id = module.security.web_managed_identity_principal_id
  api_managed_identity_principal_id = module.security.api_managed_identity_principal_id
  private_dns_zone_acr_id         = module.network.private_dns_zone_acr_id
  nat_gateway_id                  = module.network.nat_gateway_id
  redis_connection_string_secret  = module.database.redis_connection_string
  catalog_db_connection_secret    = module.database.catalog_connection_string
  identity_db_connection_secret   = module.database.identity_connection_string
  jwt_secret_key_value            = module.security.jwt_secret_key_value
}

# ---------------------------------------------------------------------------
# CI/CD (GitHub Actions OIDC, ACR push role assignments)
# ---------------------------------------------------------------------------
module "ci_cd" {
  source = "./modules/ci_cd"

  resource_group_name              = azurerm_resource_group.main.name
  location                         = var.location
  project                          = var.project
  environment                      = var.environment
  tags                             = var.tags
  github_org                       = var.github_org
  github_repo                      = var.github_repo
  subscription_id                  = var.subscription_id
  acr_id                           = module.compute.acr_id
  acr_login_server                 = module.compute.acr_login_server
  web_container_app_id             = module.compute.web_container_app_id
  api_container_app_id             = module.compute.api_container_app_id
  resource_group_id                = azurerm_resource_group.main.id
  key_vault_id                     = module.security.key_vault_id
  log_analytics_workspace_id       = module.monitoring.log_analytics_workspace_id
  cicd_service_principal_object_id = module.security.cicd_service_principal_object_id
}
