targetScope = 'resourceGroup'

@description('The location for the resources.')
param location string = resourceGroup().location

@description('The prefix for the App Service and App Service Plan names.')
param appNamePrefix string = 'webapp'

@description('The SKU for the App Service Plan.')
@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
  'P1v3'
  'P2v3'
  'P3v3'
])
param appServicePlanSkuName string = 'S1'

var uniqueSuffix = uniqueString(resourceGroup().id)
var appServicePlanName = '${appNamePrefix}-plan-${uniqueSuffix}'
var webAppName = '${appNamePrefix}-app-${uniqueSuffix}'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSkuName
  }
  properties: {
    reserved: true // Required for Linux
  }
}

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: webAppName
  location: location
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
      http20Enabled: true
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
  }
}

output webAppHostname string = webApp.properties.defaultHostName
output webAppPrincipalId string = webApp.identity.principalId