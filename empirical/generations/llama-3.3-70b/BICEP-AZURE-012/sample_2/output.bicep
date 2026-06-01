param location string = resourceGroup().location
param functionAppName string = 'eventdrivenfunctionapp'
param storageAccountName string = 'eventdrivenstorage'
param functionAppRuntime string = 'dotnet6'
param functionAppWorkerRuntime string = 'dotnet'

resource storageAccountResource 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
  }
}

resource functionAppResource 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  properties: {
    serverFarmId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/serverfarms/ConsumptionPlan'
    siteConfig: {
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/azure-functions/dotnet:6.0-appservice'
      ftpsState: 'FtpsOnly'
      httpsOnly: true
    }
    storageAccount: storageAccountName
  }
  dependsOn: [
    storageAccountResource
  ]
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    family: 'Y'
    size: 'Y1'
    capacity: 0
  }
}

resource functionAppIdentity 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  properties: {
    identity: {
      type: 'SystemAssigned'
    }
  }
  dependsOn: [
    functionAppResource
  ]
}

output functionAppNameOutput string = functionAppName
output functionAppIdOutput string = functionAppResource.id
output functionAppIdentityOutput string = functionAppIdentity.properties.identity.tenantId
output functionAppPrincipalIdOutput string = functionAppIdentity.properties.identity.principalId
output functionAppResourceIdOutput string = functionAppIdentity.id