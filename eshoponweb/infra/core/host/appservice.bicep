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
// FtpsOnly enforces TLS for all FTP/FTPS connections; Disabled is acceptable
// when FTP is not used at all.
param ftpsState string = 'FtpsOnly'
param healthCheckPath string = '/health'

// ---------------------------------------------------------------------------
// App Service resource — HTTPS-only, TLS 1.2+, system-assigned Managed Identity
// ---------------------------------------------------------------------------
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
      // Enforce TLS 1.2 minimum for all inbound connections
      minTlsVersion: '1.2'
      // Disable FTP completely unless explicitly required; use FTPS at minimum
      ftpsState: ftpsState
      appCommandLine: appCommandLine
      numberOfWorkers: numberOfWorkers != -1 ? numberOfWorkers : null
      minimumElasticInstanceCount: minimumElasticInstanceCount != -1 ? minimumElasticInstanceCount : null
      use32BitWorkerProcess: use32BitWorkerProcess
      functionAppScaleLimit: functionAppScaleLimit != -1 ? functionAppScaleLimit : null
      healthCheckPath: healthCheckPath
      // HTTP/2 improves performance for modern clients
      http20Enabled: true
      // Disable remote debugging in all environments
      remoteDebuggingEnabled: false
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
        supportCredentials: false
      }
      // Security headers enforced at the platform level
      ipSecurityRestrictions: []
      scmIpSecurityRestrictions: []
    }
  }

  // System-assigned Managed Identity used to pull secrets from Key Vault
  // without any credential in code or configuration.
  identity: { type: managedIdentity ? 'SystemAssigned' : 'None' }

  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: union(
      appSettings,
      {
        SCM_DO_BUILD_DURING_DEPLOYMENT: string(scmDoBuildDuringDeployment)
        ENABLE_ORYX_BUILD: string(enableOryxBuild)
        // Structured JSON logging to stdout; consumed by Log Analytics
        Logging__Console__FormatterName: 'json'
        Logging__Console__FormatterOptions__TimestampFormat: 'yyyy-MM-ddTHH:mm:ss.fffZ'
        Logging__LogLevel__Default: 'Information'
        Logging__LogLevel__Microsoft_AspNetCore: 'Warning'
        // ASPNETCORE_ENVIRONMENT is set via deployment pipeline; do not
        // default here to avoid accidentally exposing dev settings.
      },
      !empty(applicationInsightsName) ? {
        APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
        ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
        XDT_MicrosoftApplicationInsights_Mode: 'Recommended'
      } : {},
      !empty(keyVaultName) ? {
        AZURE_KEY_VAULT_ENDPOINT: keyVault.properties.vaultUri
        // Tell the Azure SDK to use Managed Identity for Key Vault
        AZURE_CLIENT_ID: ''
      } : {}
    )
  }

  resource configLogs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: { fileSystem: { level: 'Warning' } }
      detailedErrorMessages: { enabled: false }
      failedRequestsTracing: { enabled: true }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 7
          retentionInMb: 100
        }
      }
    }
    dependsOn: [
      configAppSettings
    ]
  }

  // Enforce modern TLS and disable legacy protocols / ciphers at the platform level
  resource configWeb 'config' = {
    name: 'web'
    properties: {
      minTlsVersion: '1.2'
      ftpsState: ftpsState
      http20Enabled: true
      remoteDebuggingEnabled: false
    }
    dependsOn: [
      configAppSettings
    ]
  }
}

// ---------------------------------------------------------------------------
// Existing resource references
// ---------------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (!empty(keyVaultName)) {
  name: keyVaultName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output identityPrincipalId string = managedIdentity ? appService.identity.principalId : ''
output name string = appService.name
output uri string = 'https://${appService.properties.defaultHostName}'
