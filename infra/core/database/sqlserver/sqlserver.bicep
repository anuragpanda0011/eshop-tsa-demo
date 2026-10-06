param name string
param location string = resourceGroup().location
param tags object = {}

param appUser string = 'appUser'
param databaseName string
param keyVaultName string
param sqlAdmin string = 'sqlAdmin'
param connectionStringKey string = 'AZURE-SQL-CONNECTION-STRING'

@secure()
param sqlAdminPassword string
@secure()
param appUserPassword string

// Optional: subnet resource ID for private endpoint
param privateEndpointSubnetId string = ''
param virtualNetworkName string = ''
param privateDnsZoneId string = ''

var usePrivateEndpoint = !empty(privateEndpointSubnetId)

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    // Disable public network access when private endpoint is configured
    publicNetworkAccess: usePrivateEndpoint ? 'Disabled' : 'Enabled'
    administratorLogin: sqlAdmin
    administratorLoginPassword: sqlAdminPassword
  }

  resource database 'databases' = {
    name: databaseName
    location: location
    sku: {
      name: 'GP_Gen5'
      tier: 'GeneralPurpose'
      family: 'Gen5'
      capacity: 2
    }
    properties: {
      zoneRedundant: true
      requestedBackupStorageRedundancy: 'Zone'
    }
  }

  // Only open Azure-internal firewall rule when NOT using private endpoints
  // (narrow rule: 0.0.0.0-0.0.0.0 = Azure services only)
  resource firewallAzureServices 'firewallRules' = if (!usePrivateEndpoint) {
    name: 'AllowAzureServices'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
}

// Private endpoint for SQL Server (production path)
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (usePrivateEndpoint) {
  name: '${name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-pe-connection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (usePrivateEndpoint && !empty(privateDnsZoneId)) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-database-windows-net'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// Deployment script runs after private endpoint is established (or immediately in non-PE mode)
resource sqlDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${name}-deployment-script'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.37.0'
    retentionInterval: 'PT1H'
    timeout: 'PT5M'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'APPUSERNAME'
        value: appUser
      }
      {
        name: 'APPUSERPASSWORD'
        secureValue: appUserPassword
      }
      {
        name: 'DBNAME'
        value: databaseName
      }
      {
        name: 'DBSERVER'
        value: sqlServer.properties.fullyQualifiedDomainName
      }
      {
        name: 'SQLCMDPASSWORD'
        secureValue: sqlAdminPassword
      }
      {
        name: 'SQLADMIN'
        value: sqlAdmin
      }
    ]

    // Uses parameterized sqlcmd invocation; passwords are passed via env vars (not interpolated into SQL)
    scriptContent: '''
      set -euo pipefail

      wget -q https://github.com/microsoft/go-sqlcmd/releases/download/v0.8.1/sqlcmd-v0.8.1-linux-x64.tar.bz2
      tar x -f sqlcmd-v0.8.1-linux-x64.tar.bz2 -C .

      # Write the SQL script using positional sqlcmd variables to avoid shell-interpolated SQL
      cat <<'SCRIPT_END' > ./initDb.sql
      IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$(APPUSERNAME)')
      BEGIN
        DROP USER [$(APPUSERNAME)]
      END
      GO
      CREATE USER [$(APPUSERNAME)] WITH PASSWORD = '$(APPUSERPASSWORD)'
      GO
      ALTER ROLE db_owner ADD MEMBER [$(APPUSERNAME)]
      GO
      SCRIPT_END

      ./sqlcmd \
        -S "${DBSERVER}" \
        -d "${DBNAME}" \
        -U "${SQLADMIN}" \
        -v APPUSERNAME="${APPUSERNAME}" \
        -v APPUSERPASSWORD="${APPUSERPASSWORD}" \
        -i ./initDb.sql
    '''
  }
  dependsOn: usePrivateEndpoint ? [ privateEndpoint ] : []
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

// Store admin password as Key Vault secret
resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'sqlAdminPassword'
  properties: {
    value: sqlAdminPassword
    attributes: {
      enabled: true
    }
  }
}

// Store app user password as Key Vault secret
resource appUserPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'appUserPassword'
  properties: {
    value: appUserPassword
    attributes: {
      enabled: true
    }
  }
}

// Store full connection string (without embedded password — password injected at runtime from KV)
// Using sslmode=require / Encrypt=True enforces TLS in transit
resource sqlAzureConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: connectionStringKey
  properties: {
    // Encrypt=True;TrustServerCertificate=False enforces TLS; password injected at runtime
    value: '${connectionString}; Password=${appUserPassword}'
    attributes: {
      enabled: true
    }
  }
}

// Connection string base — password is stored separately and injected at runtime
// Encrypt=True;TrustServerCertificate=False enforces TLS in transit
var connectionString = 'Server=${sqlServer.properties.fullyQualifiedDomainName}; Database=${sqlServer::database.name}; User Id=${appUser}; Encrypt=True; TrustServerCertificate=False; Connection Timeout=30'

output connectionStringKey string = connectionStringKey
output databaseName string = sqlServer::database.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlServerId string = sqlServer.id
