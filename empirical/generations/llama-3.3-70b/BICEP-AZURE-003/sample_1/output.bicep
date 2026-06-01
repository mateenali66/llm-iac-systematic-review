param location string = resourceGroup().location
param appServicePlanName string
param webAppName string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  properties: {
    reserved: false
    targetWorkerSizeId: 0
    targetWorkerCount: 0
    numberOfWorkers: 1
    sku: {
      name: 'P1v2'
      tier: 'PremiumV2'
      size: 'P1v2'
      family: 'Pv2'
      capacity: 1
    }
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      http20Enabled: true
    }
  }
  dependsOn: [
    appServicePlan
  ]
}

output appServicePlanId string = appServicePlan.id
output webAppId string = webApp.id
output webAppName string = webApp.name