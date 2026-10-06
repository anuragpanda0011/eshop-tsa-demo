param name string
param location string = resourceGroup().location
param tags object = {}

param kind string = ''
// reserved = true is required for Linux plans
param reserved bool = true
param sku object

// Zone redundancy for production workloads
param zoneRedundant bool = false

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: name
  location: location
  tags: tags
  sku: sku
  kind: kind
  properties: {
    reserved: reserved
    // Zone redundancy requires PremiumV3 or ElasticPremium SKU and at least 3 instances
    zoneRedundant: zoneRedundant
  }
}

// Diagnostic settings — forward plan-level metrics to Log Analytics if workspace ID provided
param logAnalyticsWorkspaceId string = ''

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: appServicePlan
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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

output id string = appServicePlan.id
output name string = appServicePlan.name
