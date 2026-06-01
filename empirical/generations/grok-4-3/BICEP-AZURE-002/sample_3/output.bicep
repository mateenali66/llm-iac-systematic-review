param storageAccountName string
param location string = resourceGroup().location
param skuName string = 'Standard_ZRS'
param staticWebsiteIndexDocument string = 'index.html'
param staticWebsiteErrorDocument string = 'error.html'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    accessTier: 'Hot'
    encryption: {
      services: {
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource staticWebsite 'Microsoft.Storage/storageAccounts/staticWebsite@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    enabled: true
    indexDocument: staticWebsiteIndexDocument
    errorDocument404Path: staticWebsiteErrorDocument
  }
}