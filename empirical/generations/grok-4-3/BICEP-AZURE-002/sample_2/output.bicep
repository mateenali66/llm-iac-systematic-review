param location string = resourceGroup().location
param storageAccountName string
param skuName string = 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
}

resource staticWebsite 'Microsoft.Storage/storageAccounts/staticWebsite@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    enabled: true
    indexDocument: 'index.html'
    errorDocument404Path: '404.html'
  }
}