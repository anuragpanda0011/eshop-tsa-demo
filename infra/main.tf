# ---------------------------------------------------------------------------
# Resource Groups
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}-${var.environment}"
  location = var.primary_location
  tags     = var.tags
}

resource "azurerm_resource_group" "secondary" {
  name     = "rg-${var.project}-${var.environment}-secondary"
  location = var.secondary_location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Monitoring (must come first — other modules depend on law/ai IDs)
# ---------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.primary_location
  project             = var.project
  environment         = var.environment
  log_retention_days  = var.log_retention_days
  alert_email         = var.alert_email
  enable_law_cmk      = var.enable_law_cmk
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.primary_location
  project                      = var.project
  environment                  = var.environment
  vnet_address_space           = var.vnet_address_space
  ddos_protection_plan_enabled = var.ddos_protection_plan_enabled
  log_analytics_workspace_id   = module.monitoring.log_analytics_workspace_id
  tags                         = var.tags
}

# ---------------------------------------------------------------------------
# Security / Identity (Key Vault, Managed Identity, Front Door, WAF)
# ---------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.primary_location
  project                    = var.project
  environment                = var.environment
  kv_sku                     = var.kv_sku
  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id
  vnet_id                    = module.network.vnet_id
  sql_admin_password         = var.sql_admin_password
  sql_admin_login            = var.sql_admin_login
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = var.tags

  depends_on = [module.network, module.monitoring]
}

# ---------------------------------------------------------------------------
# Database (SQL, Redis, Blob Storage)
# ---------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  resource_group_name           = azurerm_resource_group.main.name
  location                      = var.primary_location
  project                       = var.project
  environment                   = var.environment
  sql_admin_login               = var.sql_admin_login
  sql_admin_password            = var.sql_admin_password
  sql_catalog_sku               = var.sql_catalog_sku
  sql_identity_sku              = var.sql_identity_sku
  redis_sku                     = var.redis_sku
  redis_family                  = var.redis_family
  redis_capacity                = var.redis_capacity
  private_endpoint_subnet_id    = module.network.private_endpoint_subnet_id
  vnet_id                       = module.network.vnet_id
  key_vault_id                  = module.security.key_vault_id
  managed_identity_principal_id = module.security.managed_identity_principal_id
  log_analytics_workspace_id    = module.monitoring.log_analytics_workspace_id
  tags                          = var.tags

  depends_on = [module.network, module.security]
}

# ---------------------------------------------------------------------------
# Compute (ACR, Container Apps, Static Web Apps)
# ---------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  resource_group_name           = azurerm_resource_group.main.name
  secondary_resource_group_name = azurerm_resource_group.secondary.name
  location                      = var.primary_location
  secondary_location            = var.secondary_location
  project                       = var.project
  environment                   = var.environment
  acr_sku                       = var.acr_sku
  web_image                     = var.web_image
  api_image                     = var.api_image
  web_min_replicas              = var.web_min_replicas
  web_max_replicas              = var.web_max_replicas
  api_min_replicas              = var.api_min_replicas
  api_max_replicas              = var.api_max_replicas
  aca_infra_subnet_id           = module.network.aca_infra_subnet_id
  private_endpoint_subnet_id    = module.network.private_endpoint_subnet_id
  vnet_id                       = module.network.vnet_id
  managed_identity_id           = module.security.managed_identity_id
  managed_identity_client_id    = module.security.managed_identity_client_id
  managed_identity_principal_id = module.security.managed_identity_principal_id
  key_vault_uri                 = module.security.key_vault_uri
  key_vault_id                  = module.security.key_vault_id
  log_analytics_workspace_id    = module.monitoring.log_analytics_workspace_id
  app_insights_connection_string = module.monitoring.connection_string
  catalog_sql_connection_kv_secret_name  = module.database.catalog_conn_kv_secret_name
  identity_sql_connection_kv_secret_name = module.database.identity_conn_kv_secret_name
  redis_connection_kv_secret_name        = module.database.redis_conn_kv_secret_name
  swa_sku                       = var.swa_sku
  github_repo_url               = var.github_repo_url
  github_repo_branch            = var.github_repo_branch
  tags                          = var.tags

  depends_on = [module.network, module.security, module.database, module.monitoring]
}

# ---------------------------------------------------------------------------
# CI/CD (Service Principal, Federated Credential, RBAC)
# ---------------------------------------------------------------------------
module "ci_cd" {
  source = "./modules/ci_cd"

  project             = var.project
  environment         = var.environment
  github_org          = var.github_org
  github_repo_name    = var.github_repo_name
  resource_group_name = azurerm_resource_group.main.name
  subscription_id     = var.subscription_id
  acr_id              = module.compute.acr_id
  aca_web_id          = module.compute.aca_web_id
  aca_api_id          = module.compute.aca_api_id
  managed_identity_id = module.security.managed_identity_id
  key_vault_id        = module.security.key_vault_id
  tags                = var.tags

  depends_on = [module.compute, module.security]
}
