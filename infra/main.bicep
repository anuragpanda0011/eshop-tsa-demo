targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment; used to generate a short unique hash for all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources.')
param location string

// ---------------------------------------------------------------------------
// Optional overrides for resource names (supply via main.parameters.json)
// ---------------------------------------------------------------------------
param resourceGroupName string = ''
param webServiceName string = ''
param catalogDatabaseName string = 'catalogDatabase'
param catalogDatabaseServerName string = ''
param identityDatabaseName string = 'identityDatabase'
param identityDatabaseServerName string = ''
param appServicePlanName string = ''
param keyVaultName string = ''
param logAnalyticsWorkspaceName string = ''
param applicationInsightsName string = ''
param redisCacheName string = ''
param vnetName string = ''
param serviceBusNamespaceName string = ''

@description('Object ID of the user or service principal running the deployment; granted Key Vault Secrets Officer.')
param principalId string = ''

// Passwords are generated externally (e.g. AZD secretOrRandomPassword) and
// passed in as secure parameters — they are never hard-coded here.
@secure()
@description('SQL Server administrator password.')
param sqlAdminPassword string

@secure()
@description('Application DB user password.')
param appUserPassword string

// ---------------------------------------------------------------------------
// Naming helpers
// ---------------------------------------------------------------------------
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// ---------------------------------------------------------------------------
// Resource group
// ---------------------------------------------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// ---------------------------------------------------------------------------
// Virtual Network — provides private connectivity for all PaaS services
// ---------------------------------------------------------------------------
module vnet './core/network/vnet.bicep' = {
  name: 'vnet'
  scope: rg
  params: {
    name: !empty(vnetName) ? vnetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    location: location
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Log Analytics Workspace + Application Insights
// ---------------------------------------------------------------------------
module logAnalytics './core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
  }
}

module applicationInsights './core/monitor/applicationinsights.bicep' = {
  name: 'applicationinsights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ---------------------------------------------------------------------------
// Key Vault — RBAC model, private endpoint, audit logs → Log Analytics
// ---------------------------------------------------------------------------
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    privateEndpointSubnetId: vnet.outputs.privateEndpointSubnetId
    privateDnsZoneId: vnet.outputs.keyVaultPrivateDnsZoneId
  }
}

// ---------------------------------------------------------------------------
// Azure Cache for Redis — TLS-only (rediss://), private endpoint
// ---------------------------------------------------------------------------
module redisCache './core/cache/redis.bicep' = {
  name: 'redis'
  scope: rg
  params: {
    name: !empty(redisCacheName) ? redisCacheName : '${abbrs.cacheRedis}${resourceToken}'
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.name
    privateEndpointSubnetId: vnet.outputs.privateEndpointSubnetId
    privateDnsZoneId: vnet.outputs.redisPrivateDnsZoneId
  }
}

// ---------------------------------------------------------------------------
// Azure Service Bus — structured domain events published after every
// state-changing operation (orders, basket, catalog mutations)
// ---------------------------------------------------------------------------
module serviceBus './core/messaging/servicebus.bicep' = {
  name: 'servicebus'
  scope: rg
  params: {
    name: !empty(serviceBusNamespaceName) ? serviceBusNamespaceName : '${abbrs.serviceBusNamespaces}${resourceToken}'
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.name
    privateEndpointSubnetId: vnet.outputs.privateEndpointSubnetId
    privateDnsZoneId: vnet.outputs.serviceBusPrivateDnsZoneId
  }
}

// ---------------------------------------------------------------------------
// Catalog SQL Database — private endpoint, TLS enforced
// ---------------------------------------------------------------------------
module catalogDb './core/database/sqlserver/sqlserver.bicep' = {
  name: 'sql-catalog'
  scope: rg
  params: {
    name: !empty(catalogDatabaseServerName) ? catalogDatabaseServerName : '${abbrs.sqlServers}catalog-${resourceToken}'
    databaseName: catalogDatabaseName
    location: location
    tags: tags
    sqlAdminPassword: sqlAdminPassword
    appUserPassword: appUserPassword
    keyVaultName: keyVault.outputs.name
    connectionStringKey: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
    privateEndpointSubnetId: vnet.outputs.privateEndpointSubnetId
    privateDnsZoneId: vnet.outputs.sqlPrivateDnsZoneId
  }
}

// ---------------------------------------------------------------------------
// Identity SQL Database — private endpoint, TLS enforced
// ---------------------------------------------------------------------------
module identityDb './core/database/sqlserver/sqlserver.bicep' = {
  name: 'sql-identity'
  scope: rg
  params: {
    name: !empty(identityDatabaseServerName) ? identityDatabaseServerName : '${abbrs.sqlServers}identity-${resourceToken}'
    databaseName: identityDatabaseName
    location: location
    tags: tags
    sqlAdminPassword: sqlAdminPassword
    appUserPassword: appUserPassword
    keyVaultName: keyVault.outputs.name
    connectionStringKey: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
    privateEndpointSubnetId: vnet.outputs.privateEndpointSubnetId
    privateDnsZoneId: vnet.outputs.sqlPrivateDnsZoneId
  }
}

// ---------------------------------------------------------------------------
// App Service Plan — Linux, General Purpose
// ---------------------------------------------------------------------------
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      // P1v3 supports zone-redundancy and VNet integration
      name: 'P1v3'
      tier: 'PremiumV3'
    }
  }
}

// ---------------------------------------------------------------------------
// Web frontend App Service
// ---------------------------------------------------------------------------
module web './core/host/appservice.bicep' = {
  name: 'web'
  scope: rg
  params: {
    name: !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
    location: location
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    applicationInsightsName: applicationInsights.outputs.name
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    tags: union(tags, { 'azd-service-name': 'web' })
    healthCheckPath: '/health'
    appSettings: {
      // Key Vault references — the app reads actual values via Managed Identity
      AZURE_SQL_CATALOG_CONNECTION_STRING_KEY: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
      AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
      AZURE_KEY_VAULT_ENDPOINT: keyVault.outputs.endpoint
      // Redis — connection string fetched from Key Vault at runtime
      AZURE_REDIS_CONNECTION_STRING_KEY: 'AZURE-REDIS-CONNECTION-STRING'
      // Service Bus — connection string fetched from Key Vault at runtime
      AZURE_SERVICE_BUS_CONNECTION_STRING_KEY: 'AZURE-SERVICE-BUS-CONNECTION-STRING'
      // Structured JSON console logging
      Logging__Console__FormatterName: 'json'
      // Application Insights is wired via applicationInsightsName param above
    }
  }
}

// ---------------------------------------------------------------------------
// Key Vault RBAC — grant the web app's Managed Identity read access to secrets
// ---------------------------------------------------------------------------
module webKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'web-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: web.outputs.identityPrincipalId
  }
}

// ---------------------------------------------------------------------------
// Outputs consumed by AZD and CI/CD pipeline
// ---------------------------------------------------------------------------
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId

output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name

output AZURE_SQL_CATALOG_CONNECTION_STRING_KEY string = catalogDb.outputs.connectionStringKey
output AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY string = identityDb.outputs.connectionStringKey
output AZURE_SQL_CATALOG_DATABASE_NAME string = catalogDb.outputs.databaseName
output AZURE_SQL_IDENTITY_DATABASE_NAME string = identityDb.outputs.databaseName

output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.outputs.connectionString
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.id

output WEB_URI string = web.outputs.uri
