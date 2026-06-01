param location string = resourceGroup().location
param appName string
param appServicePlanName string = '${appName}-plan'
param planSkuName string = 'P1v3'
param planCapacity int = 1
param nodeRuntime string = 'NODE|20-lts'
param healthCheckPath string = '/healthz'
param tags object = {}

var skuTierMap = {
  F1: 'Free'
  D1: 'Shared'
  B1: 'Basic'
  B2: 'Basic'
  B3: 'Basic'
  S1: 'Standard'
  S2: 'Standard'
  S3: 'Standard'
  P1v2: 'PremiumV2'
  P2v2: 'PremiumV2'
  P3v2: 'PremiumV2'
  P1v3: 'PremiumV3'
  P2v3: 'PremiumV3'
  P3v3: 'PremiumV3'
  EP1: 'ElasticPremium'
  EP2: 'ElasticPremium'
  EP3: 'ElasticPremium'
}

resource plan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  tags: tags
  sku: {
    name: planSkuName
    tier: skuTierMap[planSkuName]
    size: planSkuName
    capacity: planCapacity
  }
  properties: {
    reserved: true
    perSiteScaling: false
  }
}

resource app 'Microsoft.Web/sites@2023-01-01' = {
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
      linuxFxVersion: nodeRuntime
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      alwaysOn: true
      http20Enabled: true
      ftpsState: 'Disabled'
      healthCheckPath: healthCheckPath
      use32BitWorkerProcess: false
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '0'
        }
      ]
    }
  }
}

output appServicePlanId string = plan.id
output webAppId string = app.id
output webAppDefaultHostName string = app.properties.defaultHostName