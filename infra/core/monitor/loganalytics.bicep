param name     string
param location string
param tags     object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 90
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
    workspaceCapping: { dailyQuotaGb: 5 }
  }
}

output id   string = workspace.id
output name string = workspace.name
