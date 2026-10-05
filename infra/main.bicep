targetScope = 'subscription'

// ─── Parameters ───────────────────────────────────────────────────────────────
@minLength(1)
@maxLength(64)
@description('Name of the environment (e.g. dev, staging, prod).')
param environmentName string

@minLength(1)
@description('Azure region for all resources.')
param location string = 'eastus2'

@description('SQL Server admin login (password comes from Key Vault).')
param sqlAdminLogin string = 'sqladmin'

@description('Entra Object ID of the team group for Key Vault admin access.')
param keyVaultAdminGroupObjectId string

@description('Frontend hostname for CORS / ALLOWED_HOSTS (e.g. www.contoso.com).')
param frontendHostname string

@description('API hostname (e.g. api.contoso.com).')
param apiHostname string

// ─── Variables ────────────────────────────────────────────────────────────────
var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  Environment: environmentName
  ManagedBy: 'Bicep/AZD'
  Application: 'eShopOnWeb'
}

// ─── Resource Group ───────────────────────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}-${resourceToken}'
  location: location
  tags: tags
}

// ─── Virtual Network ──────────────────────────────────────────────────────────
module vnet 'core/network/vnet.bicep' = {
  name: 'vnet'
  scope: rg
  params: {
    name: '${abbrs.networkVirtualNetworks}${resourceToken}'
    location: location
    tags: tags
  }
}

// ─── Log Analytics + Application Insights ────────────────────────────────────
module logAnalytics 'core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: rg
  params: {
    name: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
  }
}

module appInsights 'core/monitor/appinsights.bicep' = {
  name: 'appinsights'
  scope: rg
  params: {
    name: '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ─── Azure Container Registry ─────────────────────────────────────────────────
module acr 'core/host/containerregistry.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    adminUserEnabled: false
    zoneRedundancy: 'Enabled'
  }
}

// ─── Key Vault ────────────────────────────────────────────────────────────────
module keyVault 'core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: keyVaultAdminGroupObjectId
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    subnetId: vnet.outputs.privateEndpointSubnetId
    vnetId: vnet.outputs.id
  }
}

// ─── Azure Cache for Redis ────────────────────────────────────────────────────
module redis 'core/cache/redis.bicep' = {
  name: 'redis'
  scope: rg
  params: {
    name: '${abbrs.cacheRedis}${resourceToken}'
    location: location
    tags: tags
    subnetId: vnet.outputs.privateEndpointSubnetId
    vnetId: vnet.outputs.id
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ─── Azure SQL (Catalog DB) ───────────────────────────────────────────────────
module catalogSql 'core/database/sqlserver/sqlserver.bicep' = {
  name: 'catalogsql'
  scope: rg
  params: {
    name: '${abbrs.sqlServers}catalog-${resourceToken}'
    location: location
    tags: tags
    administratorLogin: sqlAdminLogin
    administratorLoginPasswordSecretUri: keyVault.outputs.sqlCatalogPasswordSecretUri
    databaseName: 'catalogdb'
    subnetId: vnet.outputs.privateEndpointSubnetId
    vnetId: vnet.outputs.id
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ─── Azure SQL (Identity DB) ──────────────────────────────────────────────────
module identitySql 'core/database/sqlserver/sqlserver.bicep' = {
  name: 'identitysql'
  scope: rg
  params: {
    name: '${abbrs.sqlServers}identity-${resourceToken}'
    location: location
    tags: tags
    administratorLogin: sqlAdminLogin
    administratorLoginPasswordSecretUri: keyVault.outputs.sqlIdentityPasswordSecretUri
    databaseName: 'identitydb'
    subnetId: vnet.outputs.privateEndpointSubnetId
    vnetId: vnet.outputs.id
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ─── Container Apps Environment ───────────────────────────────────────────────
module containerAppsEnv 'core/host/containerappsenvironment.bicep' = {
  name: 'containerappsenvironment'
  scope: rg
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    appInsightsConnectionString: appInsights.outputs.connectionString
    subnetId: vnet.outputs.containerAppsSubnetId
  }
}

// ─── Web Frontend Container App ───────────────────────────────────────────────
module webApp 'core/host/containerapp.bicep' = {
  name: 'webapp'
  scope: rg
  params: {
    name: '${abbrs.appContainerApps}web-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'web' })
    containerAppsEnvironmentId: containerAppsEnv.outputs.id
    containerImage: 'mcr.microsoft.com/dotnet/samples:aspnetapp'   // replaced by CI/CD
    containerPort: 8080
    external: true
    minReplicas: 1
    maxReplicas: 10
    cpuCores: '0.5'
    memoryGi: '1.0'
    keyVaultName: keyVault.outputs.name
    acrLoginServer: acr.outputs.loginServer
    environmentVariables: [
      { name: 'ASPNETCORE_ENVIRONMENT',          value: 'Production' }
      { name: 'LOG_LEVEL',                        value: 'Information' }
      { name: 'PAGE_SIZE',                        value: '10' }
      { name: 'CORS_ORIGINS',                     value: 'https://${frontendHostname}' }
      { name: 'ALLOWED_HOSTS',                    value: '${frontendHostname}' }
      { name: 'USE_AZURE_KEY_VAULT',              value: 'true' }
      { name: 'DATA_PROTECTION_BLOB_CONTAINER',   value: 'dataprotection' }
      { name: 'APPINSIGHTS_CONNECTION_STRING',    value: appInsights.outputs.connectionString }
      {
        name: 'ConnectionStrings__CatalogConnection'
        secretRef: 'catalog-connection-string'
      }
      {
        name: 'ConnectionStrings__IdentityConnection'
        secretRef: 'identity-connection-string'
      }
      {
        name: 'ConnectionStrings__Redis'
        secretRef: 'redis-connection-string'
      }
    ]
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ─── PublicApi Container App ──────────────────────────────────────────────────
module apiApp 'core/host/containerapp.bicep' = {
  name: 'apiapp'
  scope: rg
  params: {
    name: '${abbrs.appContainerApps}api-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'api' })
    containerAppsEnvironmentId: containerAppsEnv.outputs.id
    containerImage: 'mcr.microsoft.com/dotnet/samples:aspnetapp'   // replaced by CI/CD
    containerPort: 8081
    external: false    // internal ingress only; Front Door reaches it via VNET
    minReplicas: 1
    maxReplicas: 10
    cpuCores: '0.5'
    memoryGi: '1.0'
    keyVaultName: keyVault.outputs.name
    acrLoginServer: acr.outputs.loginServer
    environmentVariables: [
      { name: 'ASPNETCORE_ENVIRONMENT',        value: 'Production' }
      { name: 'LOG_LEVEL',                      value: 'Information' }
      { name: 'PAGE_SIZE',                      value: '10' }
      { name: 'JWT_ALGORITHM',                  value: 'HS256' }
      { name: 'CORS_ORIGINS',                   value: 'https://${frontendHostname}' }
      { name: 'ALLOWED_HOSTS',                  value: '${apiHostname}' }
      { name: 'USE_AZURE_KEY_VAULT',            value: 'true' }
      { name: 'APPINSIGHTS_CONNECTION_STRING',  value: appInsights.outputs.connectionString }
      {
        name: 'ConnectionStrings__CatalogConnection'
        secretRef: 'catalog-connection-string'
      }
      {
        name: 'ConnectionStrings__IdentityConnection'
        secretRef: 'identity-connection-string'
      }
      {
        name: 'ConnectionStrings__Redis'
        secretRef: 'redis-connection-string'
      }
      {
        name: 'JWT_SECRET_KEY'
        secretRef: 'jwt-secret-key'
      }
    ]
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ─── Azure Front Door (WAF + CDN) ─────────────────────────────────────────────
module frontDoor 'core/network/frontdoor.bicep' = {
  name: 'frontdoor'
  scope: rg
  params: {
    name: '${abbrs.cdnProfiles}${resourceToken}'
    location: 'global'
    tags: tags
    webAppFqdn: webApp.outputs.fqdn
    apiFqdn: apiApp.outputs.fqdn
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────────
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.loginServer
output AZURE_KEY_VAULT_NAME              string = keyVault.outputs.name
output WEB_APP_URL                       string = 'https://${webApp.outputs.fqdn}'
output API_URL                           string = 'https://${apiApp.outputs.fqdn}'
output FRONT_DOOR_ENDPOINT               string = frontDoor.outputs.endpoint
output LOG_ANALYTICS_WORKSPACE_ID        string = logAnalytics.outputs.id
output APP_INSIGHTS_CONNECTION_STRING    string = appInsights.outputs.connectionString
