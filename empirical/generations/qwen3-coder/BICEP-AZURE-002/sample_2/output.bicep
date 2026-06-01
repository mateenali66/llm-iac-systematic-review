param location string = resourceGroup().location
param storageAccountName string = 'appstatic${uniqueString(resourceGroup().id)}'
param sku string = 'Standard_LRS'
param allowBlobPublicAccess bool = false

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: toLower(storageAccountName)
  location: location
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: allowBlobPublicAccess
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource staticAssetsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'static-assets'
  parent: blobService
  properties: {
    publicAccess: allowBlobPublicAccess ? 'Blob' : 'None'
    metadata: {}
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output staticAssetsContainerName string = staticAssetsContainer.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints