param name string
param location string = resourceGroup().location
param tags object = {}

// principalId is used to grant the deploying user/SPN Key Vault Secrets
// Officer access so that deployment scripts can write secrets.
param principalId string = ''

// Log Analytics workspace resource ID for diagnostic settings
param logAnalyticsWorkspaceId string = ''

// Subnet resource ID for the Key Vault private endpoint (production)
param privateEndpointSubnetId string = ''
param privateDnsZoneId string = ''

// Built-in role: Key Vault Secrets Officer (manage secrets — used for the
// deployment identity so it can write connection strings and passwords)
var kvSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

// ---------------------------------------------------------------------------
// Key Vault — RBAC-authorised, purge-protected, private endpoint ready
// ---------------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    // Switch from legacy access-policy model to Azure RBAC
    enableRbacAuthorization: true
    // Soft-delete and purge protection prevent accidental or malicious secret loss
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    // Disable public network access when a private endpoint is supplied;
    // allow in dev/test when no subnet is provided.
    publicNetworkAccess: empty(privateEndpointSubnetId) ? 'Enabled' : 'Disabled'
    networkAcls: empty(privateEndpointSubnetId) ? {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    } : {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
    }
  }
}

// ---------------------------------------------------------------------------
// Diagnostic settings — ship audit logs to Log Analytics
// ---------------------------------------------------------------------------
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// RBAC — grant the deploying principal Key Vault Secrets Officer so it can
// write connection strings and passwords during provisioning.
// ---------------------------------------------------------------------------
resource deployerSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(keyVault.id, principalId, kvSecretsOfficerRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsOfficerRoleId)
    principalId: principalId
    // The deploying identity may be a User or a ServicePrincipal (CI/CD);
    // 'User' covers both human operators and federated OIDC SPs in AAD.
    principalType: 'User'
    description: 'Key Vault Secrets Officer — deployment identity for ${name}'
  }
}

// ---------------------------------------------------------------------------
// Private endpoint — only created when a subnet is supplied
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
          privateLinkServiceId: keyVault.id
          groupIds: [ 'vault' ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(privateEndpointSubnetId) && !empty(privateDnsZoneId)) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output endpoint string = keyVault.properties.vaultUri
output name string = keyVault.name
output id string = keyVault.id
