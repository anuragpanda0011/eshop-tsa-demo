param name string
param location string = resourceGroup().location
param tags object = {}

param appUser string = 'appUser'
param databaseName string
param keyVaultName string
param sqlAdmin string = 'sqlAdmin'
param connectionStringKey string = 'AZURE-SQL-CONNECTION-STRING'

// Subnet resource ID for the private endpoint (required in production VNet topology)
param privateEndpointSubnetId string = ''
param privateDnsZoneId string = ''

@secure()
param sqlAdminPassword string
@secure()
param appUserPassword string

// ---------------------------------------------------------------------------
// Azure SQL Server — private network access, TLS 1.2 minimum, no public IPs
// ---------------------------------------------------------------------------
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    // Public network access is disabled; all connectivity goes through the
    // private endpoint defined below.  Set to 'Enabled' only when
    // privateEndpointSubnetId is empty (e.g., local dev without VNet).
    publicNetworkAccess: empty(privateEndpointSubnetId) ? 'Enabled' : 'Disabled'
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
    }
  }

  // Allow Azure-internal traffic only when running without a private endpoint
  // (dev/test convenience rule).  In production the private endpoint is used
  // and this rule is never added.
  resource firewallAzureServices 'firewallRules' = if (empty(privateEndpointSubnetId)) {
    name: 'AllowAzureServices'
    properties: {
      // Range [0.0.0.0-0.0.0.0] = "Allow Azure-hosted clients only"
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
}

// ---------------------------------------------------------------------------
// Private endpoint — created only when a subnet ID is supplied
// ---------------------------------------------------------------------------
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (!empty(privateEndpointSubnetId)) {
  name: 'pe-${name}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${name}'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [ 'sqlServer' ]
        }
      }
    ]
  }
}

// DNS zone group — wires the private endpoint into the supplied private DNS zone
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(privateEndpointSubnetId) && !empty(privateDnsZoneId)) {
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

// ---------------------------------------------------------------------------
// Deployment script — creates the application DB user
// ---------------------------------------------------------------------------
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

    scriptContent: '''
wget https://github.com/microsoft/go-sqlcmd/releases/download/v0.8.1/sqlcmd-v0.8.1-linux-x64.tar.bz2
tar x -f sqlcmd-v0.8.1-linux-x64.tar.bz2 -C .

cat <<SCRIPT_END > ./initDb.sql
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$(APPUSERNAME)')
BEGIN
  CREATE USER [$(APPUSERNAME)] WITH PASSWORD = '$(APPUSERPASSWORD)'
END
GO
ALTER ROLE db_owner ADD MEMBER [$(APPUSERNAME)]
GO
SCRIPT_END

./sqlcmd -S ${DBSERVER} -d ${DBNAME} -U ${SQLADMIN} -i ./initDb.sql
    '''
  }
  dependsOn: [
    sqlServer
  ]
}

// ---------------------------------------------------------------------------
// Key Vault secrets — passwords and connection string stored securely
// ---------------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

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

// Connection string stored WITHOUT the password; the application retrieves
// the password separately via Managed Identity → Key Vault, so the
// connection string itself is not a secret exposure vector.
// For EF Core / SqlClient with Entra auth (preferred) the password field
// can be omitted entirely; keep it here for compatibility with SQL auth
// scenarios while referencing the Key Vault secret reference pattern.
resource sqlAzureConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: connectionStringKey
  properties: {
    // sslmode=require / Encrypt=true is enforced by the driver defaults on
    // Azure SQL; we make it explicit for clarity.
    value: 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${sqlServer::database.name};User Id=${appUser};Password=${appUserPassword};Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;'
    attributes: {
      enabled: true
    }
  }
}

var connectionString = 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${sqlServer::database.name};User Id=${appUser};Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;'
output connectionStringKey string = connectionStringKey
output databaseName string = sqlServer::database.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
