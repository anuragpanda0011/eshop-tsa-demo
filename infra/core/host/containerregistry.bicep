param name            string
param location        string
param tags            object = {}
param adminUserEnabled bool   = false
param zoneRedundancy  string = 'Enabled'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: adminUserEnabled
    zoneRedundancy: zoneRedundancy
    publicNetworkAccess: 'Enabled'   // CI/CD agents need push access; lock down post-MVP
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      quarantinePolicy: { status: 'enabled' }
      trustPolicy: { type: 'Notary', status: 'disabled' }
      retentionPolicy: { days: 30, status: 'enabled' }
      exportPolicy: { status: 'enabled' }
    }
  }
}

output id          string = acr.id
output loginServer string = acr.properties.loginServer
output name        string = acr.name
