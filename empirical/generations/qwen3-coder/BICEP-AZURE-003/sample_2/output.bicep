param location string = resourceGroup().location
param appServicePlanName string = 'asp-${uniqueString(resourceGroup().id)}'
param webAppName string = 'webapp-${uniqueString(resourceGroup().id)}'
param skuName string = 'B1'
param skuTier string = 'Basic'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    reserved: false
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      managedPipelineMode: 'Integrated'
    }
    httpsOnly: true
    clientAffinityEnabled: false
  }
}