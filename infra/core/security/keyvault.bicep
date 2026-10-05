param name                    string
param location                string
param tags                    object = {}
param principalId             string   // Entra group OID that gets Key Vault Administrator
param logAnalyticsWorkspaceId string
param subnetId                string
param vnetId                  string

// ── Key Vault (RBAC model — no access policies) ───────────────────────────────
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true          // RBAC, not access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'        // access only via private endpoint
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// Key Vault Administrator for the ops team group
resource kvAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, principalId, 'Key Vault Administrator')
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '00482a5a-887f-4fb3-b363-3b7fe8e74483')  // Key Vault Administrator
    principalId: principalId
    principalType: 'Group'
  }
}

// Diagnostic settings → Log Analytics
resource kvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'kv-diagnostics'
  scope: kv
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'AuditEvent',          enabled: true  }
      { category: 'AzurePolicyEvaluationDetails', enabled: true }
    ]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// Private endpoint
resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${name}-plsc'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [ 'vault' ]
        }
      }
    ]
  }
}

resource kvPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource kvDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: kvPrivateDnsZone
  name: '${name}-dns-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnetId }
    registrationEnabled: false
  }
}

resource kvPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: kvPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: { privateDnsZoneId: kvPrivateDnsZone.id }
      }
    ]
  }
}

// Placeholder secrets — actual values set by ops via az cli / pipeline
resource sqlCatalogPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'SqlCatalogPassword'
  properties: { value: 'REPLACE_BEFORE_FIRST_DEPLOY' }
}

resource sqlIdentityPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'SqlIdentityPassword'
  properties: { value: 'REPLACE_BEFORE_FIRST_DEPLOY' }
}

resource jwtSecretKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'JwtSecretKey'
  properties: { value: 'REPLACE_BEFORE_FIRST_DEPLOY' }
}

resource defaultAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'DefaultAdminPassword'
  properties: { value: 'REPLACE_BEFORE_FIRST_DEPLOY' }
}

output id                          string = kv.id
output name                        string = kv.name
output uri                         string = kv.properties.vaultUri
output sqlCatalogPasswordSecretUri string = sqlCatalogPasswordSecret.properties.secretUri
output sqlIdentityPasswordSecretUri string = sqlIdentityPasswordSecret.properties.secretUri
