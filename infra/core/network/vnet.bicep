param name     string
param location string
param tags     object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      {
        // Container Apps dedicated subnet — /23 = 512 addresses
        name: 'container-apps'
        properties: {
          addressPrefix: '10.0.0.0/23'
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: { serviceName: 'Microsoft.App/environments' }
            }
          ]
        }
      }
      {
        // Private endpoints subnet
        name: 'private-endpoints'
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output id                       string = vnet.id
output containerAppsSubnetId    string = vnet.properties.subnets[0].id
output privateEndpointSubnetId  string = vnet.properties.subnets[1].id
