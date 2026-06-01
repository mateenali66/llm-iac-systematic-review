@description('Specifies the Azure location where the resources will be deployed.')
@metadata({
  description: 'The Azure region for the deployment.'
})
param location string = resourceGroup().location

@description('A prefix for the storage account name, which will be combined with a unique string to ensure global uniqueness.')
@minLength(3)
@maxLength(11)
param storageAccountNamePrefix string

@description('The SKU for the storage account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
])
param storageAccountSku string = 'Standard_LRS'

@description('The name of the index document for the static website.')
param indexDocument string = 'index.html'

@description('The name of the 404 error document for the static website.')
param error404Document string = '404.html'

@description('Tags to apply to the resources.')
param tags object = {}

var uniqueStorageAccountName = '${storageAccountNamePrefix}${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: uniqueStorageAccountName
  location: location
  tags: tags
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    encryption: {
      services: {
        blob: {
          keyType: 'Account'
          enabled: true
        }
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    isVersioningEnabled: false
    staticWebsite: {
      enabled: true
      indexDocument: indexDocument
      error404Document: error404Document
    }
  }
}

@description('The primary endpoint for the static website.')
output staticWebsitePrimaryEndpoint string = storageAccount.properties.primaryEndpoints.web