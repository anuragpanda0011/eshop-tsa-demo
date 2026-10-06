###############################################################################
# Resource Group
###############################################################################
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}-${var.environment}"
  location = var.location
  tags     = var.tags
}

###############################################################################
# Modules
###############################################################################

module "network" {
  source = "./modules/network"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  project             = var.project
  tags                = var.tags

  vnet_address_space = var.vnet_address_space
  subnets            = var.subnets
}

module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.location
  environment                  = var.environment
  project                      = var.project
  tags                         = var.tags
  log_analytics_retention_days = var.log_analytics_retention_days
  alert_action_group_email     = var.alert_action_group_email

  # Wire compute outputs into monitoring so alerts are correctly scoped
  web_app_id          = module.compute.web_app_id
  api_app_id          = module.compute.api_app_id
  web_service_plan_id = module.compute.web_service_plan_id
  web_app_hostname    = module.compute.web_app_default_hostname
  api_app_hostname    = module.compute.api_app_default_hostname
}

module "security" {
  source = "./modules/security"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  environment                = var.environment
  project                    = var.project
  tags                       = var.tags
  tenant_id                  = var.tenant_id
  kv_sku_name                = var.kv_sku_name
  acr_sku                    = var.acr_sku
  vnet_id                    = module.network.vnet_id
  kv_subnet_id               = module.network.subnet_ids["snet-keyvault"]
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  # Private DNS zones created in network module
  kv_private_dns_zone_id  = module.network.private_dns_zone_ids["privatelink.vaultcore.azure.net"]
  acr_private_dns_zone_id = module.network.private_dns_zone_ids["privatelink.azurecr.io"]
  acr_subnet_id           = module.network.subnet_ids["snet-build"]

  # These will be added after compute creates managed identities
  web_app_principal_id = module.compute.web_app_principal_id
  api_app_principal_id = module.compute.api_app_principal_id

  storage_account_id = module.compute.storage_account_id

  # Secrets to store in Key Vault (sensitive)
  # NOTE: these values land in Terraform state as sensitive entries.
  # The state blob is encrypted at rest; ensure strict RBAC on the
  # tfstate storage account. For zero-secret-in-state, pre-create
  # secrets outside Terraform and reference via data source.
  sql_catalog_connection_string  = "Server=tcp:${module.database.sql_catalog_server_fqdn},1433;Database=${var.sql_catalog_db_name};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  sql_identity_connection_string = "Server=tcp:${module.database.sql_identity_server_fqdn},1433;Database=${var.sql_identity_db_name};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  redis_connection_string        = module.database.redis_primary_connection_string
  app_insights_connection_string = module.monitoring.app_insights_connection_string
  jwt_secret_key                 = random_password.jwt_secret.result
}

module "database" {
  source = "./modules/database"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  project             = var.project
  tags                = var.tags

  sql_subnet_id   = module.network.subnet_ids["snet-sql"]
  redis_subnet_id = module.network.subnet_ids["snet-redis"]
  vnet_id         = module.network.vnet_id

  sql_catalog_server_name  = "sql-catalog-${var.project}-${var.environment}"
  sql_identity_server_name = "sql-identity-${var.project}-${var.environment}"
  sql_catalog_db_name      = var.sql_catalog_db_name
  sql_identity_db_name     = var.sql_identity_db_name
  sql_catalog_sku          = var.sql_catalog_sku
  sql_identity_sku         = var.sql_identity_sku
  sql_backup_retention_days = var.sql_backup_retention_days

  entra_sql_admin_object_id = var.entra_sql_admin_object_id
  entra_sql_admin_login     = var.entra_sql_admin_login

  redis_name     = "redis-${var.project}-${var.environment}"
  redis_capacity = var.redis_capacity
  redis_family   = var.redis_family
  redis_sku_name = var.redis_sku_name

  sql_private_dns_zone_id   = module.network.private_dns_zone_ids["privatelink.database.windows.net"]
  redis_private_dns_zone_id = module.network.private_dns_zone_ids["privatelink.redis.cache.windows.net"]

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  storage_account_id = module.compute.storage_account_id
}

module "compute" {
  source = "./modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  project             = var.project
  tags                = var.tags

  web_subnet_id = module.network.subnet_ids["snet-web"]
  api_subnet_id = module.network.subnet_ids["snet-api"]

  web_app_sku_name  = var.web_app_sku_name
  api_app_sku_name  = var.api_app_sku_name
  dotnet_version    = var.dotnet_version
  web_min_instances = var.web_min_instances
  web_max_instances = var.web_max_instances
  api_min_instances = var.api_min_instances
  api_max_instances = var.api_max_instances

  key_vault_uri = module.security.key_vault_uri

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  storage_account_replication_type = var.storage_account_replication_type
  alert_action_group_email         = var.alert_action_group_email
}

module "ci_cd" {
  source = "./modules/ci_cd"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  project             = var.project
  tags                = var.tags

  web_app_id       = module.compute.web_app_id
  api_app_id       = module.compute.api_app_id
  web_app_hostname = module.compute.web_app_default_hostname
  api_app_hostname = module.compute.api_app_default_hostname

  custom_domain_name      = var.custom_domain_name
  dns_zone_name           = var.dns_zone_name
  dns_zone_resource_group = var.dns_zone_resource_group

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

###############################################################################
# Random secrets (generated once, stored in KV)
###############################################################################
# NOTE: random_password.sql_app_password removed — Entra-only SQL auth is used;
# no application-level SQL password is needed.

resource "random_password" "jwt_secret" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 4
  min_lower        = 4
  min_numeric      = 4
  min_special      = 4
}
