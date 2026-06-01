param location string = resourceGroup().location
param storageAccountName string
param skuName string = 'Standard_GRS'
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    allowBlobPublicAccess: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    accessTier: 'Hot'
    allowSharedKeyAccess: false
    staticWebsite: {
      enabled: true
      indexDocument: 'index.html'
      errorDocument404Path: '404.html'
    }
  }
}