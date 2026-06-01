param location string = resourceGroup().location
@description('Name of the App Service plan.')
param appServicePlanName string
@description('Name of the Web App.')
param webAppName string
@description('SKU name for the App Service plan (e.g., P1v3, P2v3, S1).')
param skuName string = 'P1v3'
@minValue(1)
@description('Instance count for the App Service plan.')
param skuCapacity int = 1
@allowed([
  'AllAllowed'
  'FtpsOnly'
  'Disabled'
])
@description('FTP/FTPS access policy for the Web App.')
param ftpsState string = 'FtpsOnly'
@description('Node.js major version or LTS string to use (e.g., 20, 20-lts).')
param nodeVersion string = '20-lts'
@description('Enable Always On for the Web App.')
param enableAlwaysOn bool = true
@description('Optional application settings for the Web App as key-value pairs.')
param appSettings object = {}
@description('Resource tags to apply to all resources.')
param tags object = {}

resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    reserved: true
    perSiteScaling: false
  }
  tags: tags
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'NODE|${nodeVersion}'
      http20Enabled: true
      alwaysOn: enableAlwaysOn
      minTlsVersion: '1.2'
      ftpsState: ftpsState
      healthCheckPath: '/health'
      appSettings: [for (k, v) in appSettings: {
        name: k
        value: string(v)
      }]
    }
  }
  tags: tags
}

output appServicePlanResourceId string = hostingPlan.id
output webAppResourceId string = webApp.id
output webAppHostname string = webApp.properties.defaultHostName