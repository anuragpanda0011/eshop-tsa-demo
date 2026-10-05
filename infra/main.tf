# ── Resource Group ────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# ── Monitoring Bootstrap (Log Analytics only — needed by security module) ─────
# A minimal monitoring instantiation to break the circular dependency between
# security (needs LAW ID for KV diag settings) and monitoring (needs KV for CMK).
# The full monitoring module references this workspace via data source and adds
# CMK linked storage, App Insights, alerts, and workbooks.
module "monitoring_bootstrap" {
  source = "./modules/monitoring_bootstrap"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  log_retention_days  = var.log_retention_days
  tags                = var.tags
}

# ── Networking ────────────────────────────────────────────────────────────────
module "network" {
  source = "./modules/network"

  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.location
  project                      = var.project
  environment                  = var.environment
  tags                         = var.tags
  vnet_address_space           = var.vnet_address_space
  subnet_aca_infra_cidr        = var.subnet_aca_infra_cidr
  subnet_aca_apps_cidr         = var.subnet_aca_apps_cidr
  subnet_pe_cidr               = var.subnet_pe_cidr
  subnet_appgw_cidr            = var.subnet_appgw_cidr
  subnet_redis_cidr            = var.subnet_redis_cidr
  subnet_agents_cidr           = var.subnet_agents_cidr
  subnet_bastion_cidr          = var.subnet_bastion_cidr
  subnet_apim_cidr             = var.subnet_apim_cidr
  log_analytics_workspace_id   = module.monitoring_bootstrap.log_analytics_workspace_id
  log_analytics_workspace_guid = var.log_analytics_workspace_guid
  custom_domain                = var.custom_domain
  dns_zone_name                = var.dns_zone_name
  dns_zone_resource_group      = var.dns_zone_resource_group
  key_vault_id                 = module.security.key_vault_id
  data_protection_key_name     = module.security.data_protection_key_name

  depends_on = [module.monitoring_bootstrap, module.security]
}

# ── Security / Identity ───────────────────────────────────────────────────────
module "security" {
  source = "./modules/security"

  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.location
  project                      = var.project
  environment                  = var.environment
  tags                         = var.tags
  subnet_pe_id                 = module.network.subnet_pe_id
  vnet_id                      = module.network.vnet_id
  log_analytics_workspace_id   = module.monitoring_bootstrap.log_analytics_workspace_id
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  current_object_id            = data.azurerm_client_config.current.object_id
  private_dns_zone_keyvault_id = module.network.private_dns_zone_keyvault_id
  private_dns_zone_blob_id     = module.network.private_dns_zone_blob_id
  subscription_id              = var.subscription_id

  depends_on = [module.network, module.monitoring_bootstrap]
}

# ── Monitoring (full — deployed after security for CMK) ───────────────────────
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  project                  = var.project
  environment              = var.environment
  log_retention_days       = var.log_retention_days
  alert_email              = var.alert_email
  tags                     = var.tags
  subscription_id          = var.subscription_id
  health_check_url         = module.network.front_door_endpoint_hostname
  key_vault_id             = module.security.key_vault_id
  data_protection_key_name = module.security.data_protection_key_name
  subnet_pe_id             = module.network.subnet_pe_id
  private_dns_zone_blob_id = module.network.private_dns_zone_blob_id
  sampling_percentage      = var.app_insights_sampling_percentage

  depends_on = [module.network, module.security]
}

# ── Database ──────────────────────────────────────────────────────────────────
module "database" {
  source = "./modules/database"

  resource_group_name                  = azurerm_resource_group.main.name
  location                             = var.location
  project                              = var.project
  environment                          = var.environment
  tags                                 = var.tags
  subnet_pe_id                         = module.network.subnet_pe_id
  subnet_redis_id                      = module.network.subnet_redis_id
  vnet_id                              = module.network.vnet_id
  sql_sku                              = var.sql_sku
  sql_max_size_gb                      = var.sql_max_size_gb
  sql_zone_redundant                   = var.sql_zone_redundant
  redis_sku                            = var.redis_sku
  redis_family                         = var.redis_family
  redis_capacity                       = var.redis_capacity
  log_analytics_workspace_id           = module.monitoring_bootstrap.log_analytics_workspace_id
  private_dns_zone_sql_id              = module.network.private_dns_zone_sql_id
  private_dns_zone_redis_id            = module.network.private_dns_zone_redis_id
  key_vault_id                         = module.security.key_vault_id
  managed_identity_web_principal_id    = module.security.managed_identity_web_principal_id
  managed_identity_api_principal_id    = module.security.managed_identity_api_principal_id
  aad_sql_admin_object_id              = var.aad_sql_admin_object_id
  tenant_id                            = data.azurerm_client_config.current.tenant_id
  audit_storage_account_id             = module.security.audit_storage_account_id
  audit_storage_primary_blob_endpoint  = module.security.audit_storage_primary_blob_endpoint
  audit_storage_subscription_id        = var.subscription_id

  depends_on = [module.network, module.security, module.monitoring_bootstrap]
}

# ── Compute ───────────────────────────────────────────────────────────────────
module "compute" {
  source = "./modules/compute"

  resource_group_name                 = azurerm_resource_group.main.name
  location                            = var.location
  location_secondary                  = var.location_secondary
  project                             = var.project
  environment                         = var.environment
  tags                                = var.tags
  subnet_aca_infra_id                 = module.network.subnet_aca_infra_id
  subnet_apim_id                      = module.network.subnet_apim_id
  vnet_id                             = module.network.vnet_id
  subnet_pe_id                        = module.network.subnet_pe_id
  private_dns_zone_acr_id             = module.network.private_dns_zone_acr_id
  private_dns_zone_blob_id            = module.network.private_dns_zone_blob_id
  key_vault_id                        = module.security.key_vault_id
  key_vault_uri                       = module.security.key_vault_uri
  managed_identity_web_id             = module.security.managed_identity_web_id
  managed_identity_api_id             = module.security.managed_identity_api_id
  managed_identity_apim_id            = module.security.managed_identity_apim_id
  managed_identity_web_client_id      = module.security.managed_identity_web_client_id
  managed_identity_api_client_id      = module.security.managed_identity_api_client_id
  managed_identity_web_principal_id   = module.security.managed_identity_web_principal_id
  managed_identity_api_principal_id   = module.security.managed_identity_api_principal_id
  app_insights_connection_string      = module.monitoring.app_insights_connection_string
  app_insights_secret_name            = module.monitoring.app_insights_secret_name
  log_analytics_workspace_id          = module.monitoring_bootstrap.log_analytics_workspace_id
  web_image                           = var.web_image
  api_image                           = var.api_image
  web_min_replicas                    = var.web_min_replicas
  web_max_replicas                    = var.web_max_replicas
  api_min_replicas                    = var.api_min_replicas
  api_max_replicas                    = var.api_max_replicas
  web_cpu                             = var.web_cpu
  web_memory                          = var.web_memory
  api_cpu                             = var.api_cpu
  api_memory                          = var.api_memory
  github_repo_url                     = var.github_repo_url
  github_branch                       = var.github_branch
  swa_sku_tier                        = var.swa_sku_tier
  swa_aad_client_id                   = var.swa_aad_client_id
  swa_aad_client_secret               = var.swa_aad_client_secret
  apim_publisher_email                = var.apim_publisher_email
  apim_publisher_name                 = var.apim_publisher_name
  apim_sku                            = var.apim_sku
  apim_tenant_id                      = var.apim_tenant_id
  apim_audience                       = var.apim_audience
  front_door_id                       = module.network.front_door_id
  nat_gateway_id                      = module.network.nat_gateway_id
  data_protection_key_id              = module.security.data_protection_key_id
  data_protection_key_name            = module.security.data_protection_key_name
  custom_domain                       = var.custom_domain

  depends_on = [module.network, module.security, module.database, module.monitoring]
}

# ── CI/CD ─────────────────────────────────────────────────────────────────────
module "ci_cd" {
  source = "./modules/ci_cd"

  resource_group_name              = azurerm_resource_group.main.name
  location                         = var.location
  project                          = var.project
  environment                      = var.environment
  tags                             = var.tags
  subscription_id                  = var.subscription_id
  tenant_id                        = data.azurerm_client_config.current.tenant_id
  github_org                       = var.github_org
  github_repo                      = var.github_repo
  github_branch                    = var.github_branch
  acr_id                           = module.compute.acr_id
  acr_login_server                 = module.compute.acr_login_server
  aca_web_id                       = module.compute.aca_web_id
  aca_api_id                       = module.compute.aca_api_id
  aca_environment_id               = module.compute.aca_environment_id
  key_vault_id                     = module.security.key_vault_id
  managed_identity_web_id          = module.security.managed_identity_web_id
  managed_identity_api_id          = module.security.managed_identity_api_id
  front_door_hostname              = module.network.front_door_endpoint_hostname
  # FIX: Pass resource group ID for scoped Reader assignment (not subscription)
  resource_group_id                = azurerm_resource_group.main.id

  depends_on = [module.compute, module.security]
}

# ── Data Sources ──────────────────────────────────────────────────────────────
data "azurerm_client_config" "current" {}
