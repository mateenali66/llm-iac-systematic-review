param location string = resourceGroup().location
param functionAppName string = 'eventDrivenFunctionApp'
param storageAccountName string = 'eventdrivenstorage'
param runtime string = 'dotnet6'

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
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/azure-functions/dotnet:6.0'
      ftpsState: 'Disabled'
      http20Enabled: true
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
  dependsOn: [
    storageAccountResource
  ]
}

resource functionAppStorage 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${functionAppName}/azurestorage'
  properties: {
    azureStorageConnectionString: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountResource.listKeys().keys[0].value};BlobEndpoint=https://${storageAccountName}.blob.core.windows.net/'
  }
  dependsOn: [
    functionAppResource
  ]
}