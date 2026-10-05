param name string
param location string = resourceGroup().location
param tags object = {}

param kind string = ''
// reserved = true is required for Linux-based App Service Plans
param reserved bool = true
param sku object

// ---------------------------------------------------------------------------
// App Service Plan
// ---------------------------------------------------------------------------
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: name
  location: location
  tags: tags
  sku: sku
  kind: kind
  properties: {
    reserved: reserved
    // Zone redundancy requires Premium v2/v3 SKU; guard with a condition so
    // lower-tier SKUs (B1 etc.) do not fail.
    zoneRedundant: contains(['P1v3', 'P2v3', 'P3v3', 'P1v2', 'P2v2', 'P3v2'], sku.name)
  }
}

output id string = appServicePlan.id
output name string = appServicePlan.name
