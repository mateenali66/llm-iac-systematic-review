@description('The Azure region where all resources should be deployed.')
param location string = resourceGroup().location

@description('A prefix used for all resource names.')
@minLength(3)
@maxLength(12)
param appNamePrefix string

@description('The SKU for the App Service Plan.')
param appServicePlanSku object = {
  name: 'P1v3'
  tier: 'PremiumV3'
  size: 'P1v3'
  family: 'Pv3'
  capacity: 1
}

var appServicePlanName = '${appNamePrefix}-asp'
var webAppName = '${appNamePrefix}-web-${uniqueString(resourceGroup().id)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: appServicePlanSku
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
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
      alwaysOn: true
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      http20Enabled: true
    }
  }
}

output webAppPrincipalId string = webApp.identity.principalId
output webAppName string = webApp.name
output webAppHostname string = webApp.properties.defaultHostName