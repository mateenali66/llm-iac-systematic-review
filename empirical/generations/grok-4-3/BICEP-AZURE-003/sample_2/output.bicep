@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the App Service Plan.')
param appServicePlanName string = 'asp-${uniqueString(resourceGroup().id)}'

@description('Name of the Web App.')
param webAppName string = 'app-${uniqueString(resourceGroup().id)}'

@description('SKU for the App Service Plan.')
param skuName string = 'B1'

@description('Tier for the App Service Plan.')
param skuTier string = 'Basic'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: true
    }
  }
}