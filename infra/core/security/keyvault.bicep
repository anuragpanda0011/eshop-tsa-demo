param name string
param location string = resourceGroup().location
param tags object = {}

// principalId for an initial RBAC assignment (e.g., deploying user / pipeline SP)
// Leave empty to skip the built-in role assignment at creation time.
param principalId string = ''

// Enable RBAC authorization model (recommended over legacy access policies)
param enableRbacAuthorization bool = true

// Soft-delete and purge protection — mandatory for production
param softDeleteRetentionInDays int = 90
param enablePurgeProtection bool = true

// Private endpoint parameters
param privateEndpointSubnetId string = ''
param privateDnsZoneId string = ''

// Log Analytics workspace for diagnostic forwarding
param logAnalyticsWorkspaceId string = ''

var usePrivateEndpoint = !empty(privateEndpointSubnetId)

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    // RBAC authorization replaces the legacy access-policy model
    enableRbacAuthorization: enableRbacAuthorization
    // Soft-delete protects against accidental or malicious deletion
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    // Purge protection prevents permanent deletion during retention window
    enablePurgeProtection: enablePurgeProtection
    // Disable public network access when private endpoint is used
    networkAcls: usePrivateEndpoint ? {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    } : {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    publicNetworkAccess: usePrivateEndpoint ? 'Disabled' : 'Enabled'
  }
}

// Optional private endpoint for Key Vault
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
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
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
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// Diagnostic settings — forward audit logs to Log Analytics
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

// 'Key Vault Secrets User' built-in role: 4633458b-17de-408a-b874-0445c86b69e6
var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// Grant the caller principal read access via RBAC (only when RBAC model is active and principalId provided)
resource initialRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableRbacAuthorization && !empty(principalId)) {
  name: guid(keyVault.id, principalId, secretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output endpoint string = keyVault.properties.vaultUri
output name string = keyVault.name
output id string = keyVault.id
