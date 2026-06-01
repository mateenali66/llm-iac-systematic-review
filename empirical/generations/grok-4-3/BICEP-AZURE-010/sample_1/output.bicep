@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the storage account.')
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('Name of the CDN profile.')
param cdnProfileName string = 'cdn${uniqueString(resourceGroup().id)}'

@description('Name of the CDN endpoint.')
param cdnEndpointName string = 'cdn${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'uploads'
  properties: {
    publicAccess: 'Blob'
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'backups'
  properties: {
    publicAccess: 'None'
  }
}

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: cdnProfileName
  location: location
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  parent: cdnProfile
  name: cdnEndpointName
  location: location
  properties: {
    originHostHeader: storageAccount.properties.primaryEndpoints.blob
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'BypassCaching'
    origins: [
      {
        name: 'origin'
        properties: {
          hostName: storageAccount.properties.primaryEndpoints.blob
          httpsPort: 443
          originHostHeader: storageAccount.properties.primaryEndpoints.blob
        }
      }
    ]
  }
}