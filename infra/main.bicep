targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters to override the default azd resource naming conventions.
param resourceGroupName string = ''
param webServiceName string = ''
param apiServiceName string = ''
param catalogDatabaseName string = 'catalogDatabase'
param catalogDatabaseServerName string = ''
param identityDatabaseName string = 'identityDatabase'
param identityDatabaseServerName string = ''
param appServicePlanName string = ''
param apiAppServicePlanName string = ''
param keyVaultName string = ''
param redisCacheName string = ''
param logAnalyticsWorkspaceName string = ''
param applicationInsightsName string = ''
param vnetName string = ''
param frontDoorProfileName string = ''

@description('Id of the user or app to assign application roles')
param principalId string = ''

@secure()
@description('SQL Server administrator password')
param sqlAdminPassword string

@secure()
@description('Application user password')
param appUserPassword string

@description('Enable zone-redundant SQL databases (requires General Purpose or higher)')
param sqlZoneRedundant bool = false

@description('Enable VNet integration and private endpoints')
param enableVnetIntegration bool = true

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// ---------------------------------------------------------------------------
// Log Analytics Workspace
// ---------------------------------------------------------------------------
module logAnalytics './core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsWorkspaceName)
      ? logAnalyticsWorkspaceName
      : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Application Insights
// ---------------------------------------------------------------------------
module applicationInsights './core/monitor/applicationinsights.bicep' = {
  name: 'applicationinsights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName)
      ? applicationInsightsName
      : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ---------------------------------------------------------------------------
// Virtual Network with subnets
// ---------------------------------------------------------------------------
module vnet './core/network/vnet.bicep' = if (enableVnetIntegration) {
  name: 'vnet'
  scope: rg
  params: {
    name: !empty(vnetName) ? vnetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    location: location
    tags: tags
    addressPrefixes: ['10.0.0.0/16']
    subnets: [
      {
        name: 'web-integration'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'appservice'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          serviceEndpoints: []
        }
      }
      {
        name: 'api-integration'
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: [
            {
              name: 'appservice'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          serviceEndpoints: []
        }
      }
      {
        name: 'private-endpoints'
        properties: {
          addressPrefix: '10.0.3.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'redis-integration'
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Key Vault (RBAC model)
// ---------------------------------------------------------------------------
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
    // Use RBAC authorization model instead of legacy access policies
    enableRbacAuthorization: true
    // Soft-delete protection
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: enableVnetIntegration ? 'Disabled' : 'Enabled'
  }
}

// Private endpoint for Key Vault
module keyVaultPrivateEndpoint './core/network/private-endpoint.bicep' = if (enableVnetIntegration) {
  name: 'keyvault-private-endpoint'
  scope: rg
  params: {
    name: 'pe-${keyVault.outputs.name}'
    location: location
    tags: tags
    subnetId: enableVnetIntegration ? vnet.outputs.subnetIds['private-endpoints'] : ''
    privateLinkServiceId: keyVault.outputs.id
    groupIds: ['vault']
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
    vnetId: enableVnetIntegration ? vnet.outputs.id : ''
  }
}

// ---------------------------------------------------------------------------
// Azure Cache for Redis
// ---------------------------------------------------------------------------
module redis './core/cache/redis.bicep' = {
  name: 'redis'
  scope: rg
  params: {
    name: !empty(redisCacheName) ? redisCacheName : '${abbrs.cacheRedis}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'Standard'
      family: 'C'
      capacity: 1
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    keyVaultName: keyVault.outputs.name
    connectionStringSecretName: 'AZURE-REDIS-CONNECTION-STRING'
  }
}

// Private endpoint for Redis
module redisPrivateEndpoint './core/network/private-endpoint.bicep' = if (enableVnetIntegration) {
  name: 'redis-private-endpoint'
  scope: rg
  params: {
    name: 'pe-${redis.outputs.name}'
    location: location
    tags: tags
    subnetId: enableVnetIntegration ? vnet.outputs.subnetIds['redis-integration'] : ''
    privateLinkServiceId: redis.outputs.id
    groupIds: ['redisCache']
    privateDnsZoneName: 'privatelink.redis.cache.windows.net'
    vnetId: enableVnetIntegration ? vnet.outputs.id : ''
  }
}

// ---------------------------------------------------------------------------
// App Service Plan — Web Frontend (Premium v3)
// ---------------------------------------------------------------------------
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}web-${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'P1v3'
      tier: 'PremiumV3'
      capacity: 1
    }
    kind: 'linux'
    reserved: true
  }
}

// ---------------------------------------------------------------------------
// App Service Plan — Public API (Premium v3, separate plan)
// ---------------------------------------------------------------------------
module apiAppServicePlan './core/host/appserviceplan.bicep' = {
  name: 'api-appserviceplan'
  scope: rg
  params: {
    name: !empty(apiAppServicePlanName) ? apiAppServicePlanName : '${abbrs.webServerFarms}api-${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'P1v3'
      tier: 'PremiumV3'
      capacity: 1
    }
    kind: 'linux'
    reserved: true
  }
}

// ---------------------------------------------------------------------------
// Web App (MVC + Blazor Admin)
// ---------------------------------------------------------------------------
module web './core/host/appservice.bicep' = {
  name: 'web'
  scope: rg
  params: {
    name: !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
    location: location
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    tags: union(tags, { 'azd-service-name': 'web' })
    managedIdentity: true
    vnetSubnetId: enableVnetIntegration ? vnet.outputs.subnetIds['web-integration'] : ''
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    appSettings: {
      // Key Vault references resolved via Managed Identity
      AZURE_SQL_CATALOG_CONNECTION_STRING_KEY: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
      AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
      AZURE_KEY_VAULT_ENDPOINT: keyVault.outputs.endpoint
      AZURE_KEY_VAULT_NAME: keyVault.outputs.name
      AZURE_REDIS_CONNECTION_STRING_KEY: 'AZURE-REDIS-CONNECTION-STRING'
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.outputs.connectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
      // JWT secret is read from Key Vault at runtime via IConfiguration
      JWT_SECRET_KEY_SECRET_NAME: 'JWT-SECRET-KEY'
      // Force HTTPS
      ASPNETCORE_HTTPS_PORT: '443'
      ASPNETCORE_ENVIRONMENT: 'Production'
    }
  }
}

// Web App deployment slot — staging
module webStagingSlot './core/host/appservice-slot.bicep' = {
  name: 'web-staging-slot'
  scope: rg
  params: {
    appName: web.outputs.name
    slotName: 'staging'
    location: location
    tags: union(tags, { 'azd-service-name': 'web-staging' })
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    managedIdentity: true
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    appSettings: {
      AZURE_SQL_CATALOG_CONNECTION_STRING_KEY: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
      AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
      AZURE_KEY_VAULT_ENDPOINT: keyVault.outputs.endpoint
      AZURE_KEY_VAULT_NAME: keyVault.outputs.name
      AZURE_REDIS_CONNECTION_STRING_KEY: 'AZURE-REDIS-CONNECTION-STRING'
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.outputs.connectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
      JWT_SECRET_KEY_SECRET_NAME: 'JWT-SECRET-KEY'
      ASPNETCORE_ENVIRONMENT: 'Staging'
    }
  }
}

// ---------------------------------------------------------------------------
// Public API App Service
// ---------------------------------------------------------------------------
module api './core/host/appservice.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesAppService}api-${resourceToken}'
    location: location
    appServicePlanId: apiAppServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    tags: union(tags, { 'azd-service-name': 'api' })
    managedIdentity: true
    vnetSubnetId: enableVnetIntegration ? vnet.outputs.subnetIds['api-integration'] : ''
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    appSettings: {
      AZURE_SQL_CATALOG_CONNECTION_STRING_KEY: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
      AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
      AZURE_KEY_VAULT_ENDPOINT: keyVault.outputs.endpoint
      AZURE_KEY_VAULT_NAME: keyVault.outputs.name
      AZURE_REDIS_CONNECTION_STRING_KEY: 'AZURE-REDIS-CONNECTION-STRING'
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.outputs.connectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
      JWT_SECRET_KEY_SECRET_NAME: 'JWT-SECRET-KEY'
      ASPNETCORE_ENVIRONMENT: 'Production'
    }
  }
}

// ---------------------------------------------------------------------------
// Key Vault RBAC role assignments
// Built-in role: Key Vault Secrets User = 4633458b-17de-408a-b874-0445c86b69e6
// Built-in role: Key Vault Secrets Officer = b86a8fe4-44ce-4948-aee5-eccb2c155cd7
// ---------------------------------------------------------------------------

// Web App Managed Identity → Key Vault Secrets User
module webKeyVaultRoleAssignment './core/security/keyvault-role-assignment.bicep' = {
  name: 'web-keyvault-role'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: web.outputs.identityPrincipalId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
  }
}

// Web Staging Slot Managed Identity → Key Vault Secrets User
module webStagingKeyVaultRoleAssignment './core/security/keyvault-role-assignment.bicep' = {
  name: 'web-staging-keyvault-role'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: webStagingSlot.outputs.identityPrincipalId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
  }
}

// API App Managed Identity → Key Vault Secrets User
module apiKeyVaultRoleAssignment './core/security/keyvault-role-assignment.bicep' = {
  name: 'api-keyvault-role'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: api.outputs.identityPrincipalId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
  }
}

// Developer / pipeline principal → Key Vault Secrets Officer (for seeding secrets)
module devKeyVaultRoleAssignment './core/security/keyvault-role-assignment.bicep' = if (!empty(principalId)) {
  name: 'dev-keyvault-role'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: principalId
    roleDefinitionId: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  }
}

// ---------------------------------------------------------------------------
// Catalog SQL Database
// ---------------------------------------------------------------------------
module catalogDb './core/database/sqlserver/sqlserver.bicep' = {
  name: 'sql-catalog'
  scope: rg
  params: {
    name: !empty(catalogDatabaseServerName)
      ? catalogDatabaseServerName
      : '${abbrs.sqlServers}catalog-${resourceToken}'
    databaseName: catalogDatabaseName
    location: location
    tags: tags
    sqlAdminPassword: sqlAdminPassword
    appUserPassword: appUserPassword
    keyVaultName: keyVault.outputs.name
    connectionStringKey: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
    // Lock down public network access; access via private endpoint only
    publicNetworkAccess: enableVnetIntegration ? 'Disabled' : 'Enabled'
    zoneRedundant: sqlZoneRedundant
    sku: {
      name: 'GP_Gen5_2'
      tier: 'GeneralPurpose'
    }
    // App Service Managed Identity for SQL authentication
    webAppPrincipalId: web.outputs.identityPrincipalId
    webAppPrincipalName: web.outputs.name
    apiPrincipalId: api.outputs.identityPrincipalId
    apiPrincipalName: api.outputs.name
  }
}

// Private endpoint for Catalog SQL
module catalogSqlPrivateEndpoint './core/network/private-endpoint.bicep' = if (enableVnetIntegration) {
  name: 'catalog-sql-private-endpoint'
  scope: rg
  params: {
    name: 'pe-${catalogDb.outputs.serverName}'
    location: location
    tags: tags
    subnetId: enableVnetIntegration ? vnet.outputs.subnetIds['private-endpoints'] : ''
    privateLinkServiceId: catalogDb.outputs.serverId
    groupIds: ['sqlServer']
    privateDnsZoneName: 'privatelink.database.windows.net'
    vnetId: enableVnetIntegration ? vnet.outputs.id : ''
  }
}

// ---------------------------------------------------------------------------
// Identity SQL Database
// ---------------------------------------------------------------------------
module identityDb './core/database/sqlserver/sqlserver.bicep' = {
  name: 'sql-identity'
  scope: rg
  params: {
    name: !empty(identityDatabaseServerName)
      ? identityDatabaseServerName
      : '${abbrs.sqlServers}identity-${resourceToken}'
    databaseName: identityDatabaseName
    location: location
    tags: tags
    sqlAdminPassword: sqlAdminPassword
    appUserPassword: appUserPassword
    keyVaultName: keyVault.outputs.name
    connectionStringKey: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
    publicNetworkAccess: enableVnetIntegration ? 'Disabled' : 'Enabled'
    zoneRedundant: sqlZoneRedundant
    sku: {
      name: 'GP_Gen5_2'
      tier: 'GeneralPurpose'
    }
    webAppPrincipalId: web.outputs.identityPrincipalId
    webAppPrincipalName: web.outputs.name
    apiPrincipalId: api.outputs.identityPrincipalId
    apiPrincipalName: api.outputs.name
  }
}

// Private endpoint for Identity SQL
module identitySqlPrivateEndpoint './core/network/private-endpoint.bicep' = if (enableVnetIntegration) {
  name: 'identity-sql-private-endpoint'
  scope: rg
  params: {
    name: 'pe-${identityDb.outputs.serverName}'
    location: location
    tags: tags
    subnetId: enableVnetIntegration ? vnet.outputs.subnetIds['private-endpoints'] : ''
    privateLinkServiceId: identityDb.outputs.serverId
    groupIds: ['sqlServer']
    privateDnsZoneName: 'privatelink.database.windows.net'
    vnetId: enableVnetIntegration ? vnet.outputs.id : ''
  }
}

// ---------------------------------------------------------------------------
// Azure Front Door Premium (WAF + CDN + global load balancer)
// ---------------------------------------------------------------------------
module frontDoor './core/network/frontdoor.bicep' = {
  name: 'frontdoor'
  scope: rg
  params: {
    name: !empty(frontDoorProfileName)
      ? frontDoorProfileName
      : '${abbrs.networkFrontDoors}${resourceToken}'
    location: 'global'
    tags: tags
    skuName: 'Premium_AzureFrontDoor'
    webAppHostName: web.outputs.hostname
    apiAppHostName: api.outputs.hostname
    wafMode: 'Prevention'
  }
}

// ---------------------------------------------------------------------------
// Autoscale settings for Web App Service Plan
// ---------------------------------------------------------------------------
module webAutoscale './core/host/autoscale.bicep' = {
  name: 'web-autoscale'
  scope: rg
  params: {
    name: 'autoscale-web-${resourceToken}'
    location: location
    tags: tags
    targetResourceId: appServicePlan.outputs.id
    minimumCapacity: 1
    maximumCapacity: 10
    defaultCapacity: 1
    scaleOutCpuThreshold: 70
    scaleInCpuThreshold: 30
    scaleOutCooldown: 'PT5M'
    scaleInCooldown: 'PT10M'
  }
}

// Autoscale settings for API App Service Plan
module apiAutoscale './core/host/autoscale.bicep' = {
  name: 'api-autoscale'
  scope: rg
  params: {
    name: 'autoscale-api-${resourceToken}'
    location: location
    tags: tags
    targetResourceId: apiAppServicePlan.outputs.id
    minimumCapacity: 1
    maximumCapacity: 10
    defaultCapacity: 1
    scaleOutCpuThreshold: 70
    scaleInCpuThreshold: 30
    scaleOutCooldown: 'PT5M'
    scaleInCooldown: 'PT10M'
  }
}

// ---------------------------------------------------------------------------
// Azure Monitor Alerts
// ---------------------------------------------------------------------------
module alerts './core/monitor/alerts.bicep' = {
  name: 'alerts'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    webAppId: web.outputs.id
    apiAppId: api.outputs.id
    webPlanId: appServicePlan.outputs.id
    apiPlanId: apiAppServicePlan.outputs.id
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

// Data outputs
output AZURE_SQL_CATALOG_CONNECTION_STRING_KEY string = catalogDb.outputs.connectionStringKey
output AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY string = identityDb.outputs.connectionStringKey
output AZURE_SQL_CATALOG_DATABASE_NAME string = catalogDb.outputs.databaseName
output AZURE_SQL_IDENTITY_DATABASE_NAME string = identityDb.outputs.databaseName

// App outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name

// Web outputs
output AZURE_WEB_APP_NAME string = web.outputs.name
output AZURE_WEB_APP_HOSTNAME string = web.outputs.hostname
output AZURE_WEB_APP_URI string = 'https://${web.outputs.hostname}'

// API outputs
output AZURE_API_APP_NAME string = api.outputs.name
output AZURE_API_APP_HOSTNAME string = api.outputs.hostname
output AZURE_API_APP_URI string = 'https://${api.outputs.hostname}'

// Redis outputs
output AZURE_REDIS_NAME string = redis.outputs.name

// Application Insights outputs
output AZURE_APPLICATION_INSIGHTS_NAME string = applicationInsights.outputs.name
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = applicationInsights.outputs.connectionString
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.id

// Front Door outputs
output AZURE_FRONT_DOOR_HOSTNAME string = frontDoor.outputs.frontendHostname
output AZURE_FRONT_DOOR_ID string = frontDoor.outputs.id

// VNet outputs
output AZURE_VNET_NAME string = enableVnetIntegration ? vnet.outputs.name : ''
output AZURE_VNET_ID string = enableVnetIntegration ? vnet.outputs.id : ''
