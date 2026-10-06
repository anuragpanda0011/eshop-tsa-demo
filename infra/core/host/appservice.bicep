param name string
param location string = resourceGroup().location
param tags object = {}

// Reference Properties
param applicationInsightsName string = ''
param appServicePlanId string
param keyVaultName string = ''
param managedIdentity bool = !empty(keyVaultName)

// Runtime Properties
@allowed([
  'dotnet', 'dotnetcore', 'dotnet-isolated', 'node', 'python', 'java', 'powershell', 'custom'
])
param runtimeName string
param runtimeNameAndVersion string = '${runtimeName}|${runtimeVersion}'
param runtimeVersion string

// Microsoft.Web/sites Properties
param kind string = 'app,linux'

// Microsoft.Web/sites/config
param allowedOrigins array = []
param alwaysOn bool = true
param appCommandLine string = ''
param appSettings object = {}
param clientAffinityEnabled bool = false
param enableOryxBuild bool = contains(kind, 'linux')
param functionAppScaleLimit int = -1
param linuxFxVersion string = runtimeNameAndVersion
param minimumElasticInstanceCount int = -1
param numberOfWorkers int = -1
param scmDoBuildDuringDeployment bool = false
param use32BitWorkerProcess bool = false
// Disable plain FTP entirely; FTPS only is insufficient — set to Disabled for production
param ftpsState string = 'Disabled'
param healthCheckPath string = '/health'

// Deployment slot support
param deploymentSlotsEnabled bool = false

// Autoscale settings
param autoScaleMinCount int = 1
param autoScaleMaxCount int = 10
param autoScaleDefaultCount int = 2
param autoScaleCpuThreshold int = 70

// Redis cache connection (for distributed session / data protection)
param redisCacheConnectionStringSecretName string = ''

// VNet integration
param vnetSubnetId string = ''

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    clientAffinityEnabled: clientAffinityEnabled
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      // TLS 1.2 minimum enforced
      minTlsVersion: '1.2'
      // Disable plain FTP
      ftpsState: ftpsState
      appCommandLine: appCommandLine
      numberOfWorkers: numberOfWorkers != -1 ? numberOfWorkers : null
      minimumElasticInstanceCount: minimumElasticInstanceCount != -1 ? minimumElasticInstanceCount : null
      use32BitWorkerProcess: use32BitWorkerProcess
      functionAppScaleLimit: functionAppScaleLimit != -1 ? functionAppScaleLimit : null
      healthCheckPath: healthCheckPath
      // Disable remote debugging
      remoteDebuggingEnabled: false
      // HTTP/2 enabled for better performance
      http20Enabled: true
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
        supportCredentials: false
      }
    }
    // VNet integration when subnet is provided
    virtualNetworkSubnetId: !empty(vnetSubnetId) ? vnetSubnetId : null
    vnetRouteAllEnabled: !empty(vnetSubnetId) ? true : false
  }

  // System-assigned managed identity so the app can authenticate to Key Vault, SQL, etc.
  identity: { type: managedIdentity ? 'SystemAssigned' : 'None' }

  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: union(
      appSettings,
      {
        SCM_DO_BUILD_DURING_DEPLOYMENT: string(scmDoBuildDuringDeployment)
        ENABLE_ORYX_BUILD: string(enableOryxBuild)
        // Structured JSON logging to stdout for Azure Monitor ingestion
        Logging__Console__FormatterName: 'json'
        Logging__Console__FormatterOptions__SingleLine: 'true'
        Logging__Console__FormatterOptions__IncludeScopes: 'true'
        // Enforce HTTPS for all outbound managed-service URLs at app level
        WEBSITE_HTTPLOGGING_RETENTION_DAYS: '7'
        // Health probe path for App Service / Front Door
        WEBSITE_HEALTHCHECK_MAXPINGFAILURES: '3'
      },
      !empty(applicationInsightsName) ? {
        APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
        ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
        XDT_MicrosoftApplicationInsights_Mode: 'Recommended'
      } : {},
      !empty(keyVaultName) ? {
        AZURE_KEY_VAULT_ENDPOINT: keyVault.properties.vaultUri
      } : {},
      !empty(redisCacheConnectionStringSecretName) ? {
        // Reference to KV secret for Redis — App Service resolves @Microsoft.KeyVault() references at runtime
        REDIS_CONNECTION_STRING: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${redisCacheConnectionStringSecretName})'
      } : {}
    )
  }

  resource configLogs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: { fileSystem: { level: 'Warning' } }
      detailedErrorMessages: { enabled: true }
      failedRequestsTracing: { enabled: true }
      httpLogs: { fileSystem: { enabled: true, retentionInDays: 7, retentionInMb: 35 } }
    }
    dependsOn: [
      configAppSettings
    ]
  }
}

// Staging deployment slot (blue/green deployments)
resource stagingSlot 'Microsoft.Web/sites/slots@2022-03-01' = if (deploymentSlotsEnabled) {
  parent: appService
  name: 'staging'
  location: location
  tags: tags
  kind: kind
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      remoteDebuggingEnabled: false
      http20Enabled: true
      healthCheckPath: healthCheckPath
    }
  }
  identity: { type: managedIdentity ? 'SystemAssigned' : 'None' }
}

// Autoscale settings for the App Service Plan (targets the plan, not the site)
resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${name}-autoscale'
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceUri: appServicePlanId
    profiles: [
      {
        name: 'defaultProfile'
        capacity: {
          minimum: string(autoScaleMinCount)
          maximum: string(autoScaleMaxCount)
          default: string(autoScaleDefaultCount)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlanId
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: autoScaleCpuThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlanId
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (!empty(keyVaultName)) {
  name: keyVaultName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

output identityPrincipalId string = managedIdentity ? appService.identity.principalId : ''
output name string = appService.name
output uri string = 'https://${appService.properties.defaultHostName}'
output stagingSlotPrincipalId string = (deploymentSlotsEnabled && managedIdentity) ? stagingSlot.identity.principalId : ''
output stagingSlotUri string = deploymentSlotsEnabled ? 'https://${stagingSlot.properties.defaultHostName}' : ''
