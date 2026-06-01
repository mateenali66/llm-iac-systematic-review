@description('The prefix for the Storage Account name. A unique string will be appended to this prefix.')
@minLength(3)
@maxLength(11)
param namePrefix string

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('Tags to apply to the resources.')
param tags object = {
  environment: 'production'
  application: 'static-assets'
}

var storageAccountName = '${toLower(namePrefix)}${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    staticWebsite: {
      enabled: true
      indexDocument: 'index.html'
      error404Document: '404.html'
    }
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

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryWebEndpoint string = storageAccount.properties.primaryEndpoints.web