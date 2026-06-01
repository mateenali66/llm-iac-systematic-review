param storageAccountName string = resourceGroup().name
param location string = resourceGroup().location
param managedIdentityName string = 'storage-reader-mi'

resource managedIdentity 'Microsoft.ManagedIdentity/managedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
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

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, managedIdentityName, storageAccountName, 'Storage Blob Data Reader')
  scope: storageAccount
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a2470f3e0d3b')
  }
  dependsOn: [
    managedIdentity
    storageAccount
  ]
}