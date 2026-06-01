param location string = resourceGroup().location

@description('A short prefix used for resource names')
param namePrefix string = 'node'

@description('Deployment environment name (e.g., prod, staging)')
param environment string = 'prod'

@description('Globally unique Web App name. Defaults to a unique name based on prefix and environment.')
@minLength(2)
param appName string = toLower('${namePrefix}-${environment}-${uniqueString(resourceGroup().id)}')

@description('App Service Plan SKU')
@allowed([
  'P1v3'
  'P2v3'
  'P3v3'
])
param skuName string = 'P1v3'

@description('Number of workers in the App Service Plan')
@minValue(1)
@maxValue(20)
param skuCapacity int = 1

@description('Enable zone redundancy for the App Service Plan (supported regions only)')
param zoneRedundant bool = true

@description('Common resource tags')
param tags object = {
  environment: environment
  workload: 'webapp'
}

var aspName = toLower('${namePrefix}-${environment}-asp')

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: aspName
  location: location
  kind: 'linux'
  tags: tags
  sku: {
    name: skuName
    tier: 'PremiumV3'
    size: skuName
    capacity: skuCapacity
  }
  properties: {
    reserved: true
    perSiteScaling: false
    zoneRedundant: zoneRedundant
  }
}

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: 'Disabled'
    }
  }
}

output appServicePlanId string = plan.id
output webAppName string = site.name
output webAppDefaultHostName string = site.properties.defaultHostName