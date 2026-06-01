param location string = resourceGroup().location
param functionAppName string = 'eventDrivenFunctionApp'
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
    enableHttpsOnly: true
  }
}

resource functionAppResource 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  properties: {
    serverFarmId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/serverfarms/Default1'
    siteConfig: {
      linuxFxVersion: '${functionAppRuntime}|${functionAppWorkerRuntime}'
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
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
}