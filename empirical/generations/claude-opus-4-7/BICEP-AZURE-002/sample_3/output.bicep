@description('Name of the storage account. Must be globally unique, 3-24 lowercase alphanumeric characters.')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('Azure region for the storage account.')
param location string = resourceGroup().location

@description('Storage account SKU.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param skuName string = 'Standard_ZRS'

@description('CORS allowed origins for static asset delivery.')
param allowedOrigins array = [
  '*'
]

@description('Custom domain name (optional, e.g. assets.contoso.com). Leave empty to skip.')
param customDomainName string = ''

@description('Resource tags.')
param tags object = {
  environment: 'production'
  workload: 'static-assets'
}

@description('Number of days to retain soft-deleted blobs.')
@minValue(1)
@maxValue(365)
param blobSoftDeleteRetentionDays int = 30

@description('Number of days to retain soft-deleted containers.')
@minValue(1)
@maxValue(365)
param containerSoftDeleteRetentionDays int = 30

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    customDomain: empty(customDomainName) ? null : {
      name: customDomainName
      useSubDomainName: true
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
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
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: allowedOrigins
          allowedMethods: [
            'GET'
            'HEAD'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 3600
        }
      ]
    }
    deleteRetentionPolicy: {
      enabled: true
      days: blobSoftDeleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: containerSoftDeleteRetentionDays
    }
    isVersioningEnabled: true
    changeFeed: {
      enabled: false
    }
  }
}

resource assetsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobServices
  name: 'assets'
  properties: {
    publicAccess: 'Blob'
    metadata: {
      purpose: 'static-assets'
    }
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output assetsContainerName string = assetsContainer.name
output assetsContainerUrl string = '${storageAccount.properties.primaryEndpoints.blob}${assetsContainer.name}'