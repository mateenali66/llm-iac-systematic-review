@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the storage account. Must be globally unique, 3-24 lowercase alphanumeric characters.')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('Name of the CDN profile.')
param cdnProfileName string = 'cdnp-${uniqueString(resourceGroup().id)}'

@description('Name of the CDN endpoint. Must be globally unique.')
param cdnEndpointName string = 'cdne-${uniqueString(resourceGroup().id)}'

@description('SKU for the CDN profile.')
@allowed([
  'Standard_Microsoft'
  'Standard_Akamai'
  'Standard_Verizon'
  'Premium_Verizon'
])
param cdnSku string = 'Standard_Microsoft'

@description('Tags applied to all resources.')
param tags object = {
  environment: 'production'
  managedBy: 'bicep'
}

var uploadsContainerName = 'uploads'
var backupsContainerName = 'backups'
var blobStorageOriginHostName = replace(replace(storageAccount.properties.primaryEndpoints.blob, 'https://', ''), '/', '')

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowCrossTenantReplication: false
    publicNetworkAccess: 'Enabled'
    defaultToOAuthAuthentication: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    isVersioningEnabled: true
  }
}

resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: uploadsContainerName
  properties: {
    publicAccess: 'Blob'
    metadata: {
      purpose: 'public-readable-uploads-served-via-cdn'
    }
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: backupsContainerName
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'private-backups'
    }
  }
}

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: cdnProfileName
  location: 'global'
  tags: tags
  sku: {
    name: cdnSku
  }
  properties: {}
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  parent: cdnProfile
  name: cdnEndpointName
  location: 'global'
  tags: tags
  properties: {
    originHostHeader: blobStorageOriginHostName
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    originPath: '/${uploadsContainerName}'
    contentTypesToCompress: [
      'application/json'
      'application/javascript'
      'application/xml'
      'text/css'
      'text/html'
      'text/javascript'
      'text/plain'
      'image/svg+xml'
    ]
    isCompressionEnabled: true
    origins: [
      {
        name: 'storage-origin'
        properties: {
          hostName: blobStorageOriginHostName
          httpsPort: 443
          originHostHeader: blobStorageOriginHostName
          priority: 1
          weight: 1000
          enabled: true
        }
      }
    ]
  }
  dependsOn: [
    uploadsContainer
  ]
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output uploadsContainerName string = uploadsContainer.name
output backupsContainerName string = backupsContainer.name
output cdnProfileName string = cdnProfile.name
output cdnEndpointHostName string = cdnEndpoint.properties.hostName
output cdnEndpointUrl string = 'https://${cdnEndpoint.properties.hostName}'