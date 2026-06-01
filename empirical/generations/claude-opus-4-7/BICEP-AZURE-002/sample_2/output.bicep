@description('The name of the storage account. Must be globally unique, 3-24 lowercase alphanumeric characters.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('The Azure region where the storage account will be deployed.')
param location string = resourceGroup().location

@description('The SKU of the storage account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param skuName string = 'Standard_ZRS'

@description('Environment tag value.')
@allowed([
  'dev'
  'test'
  'staging'
  'prod'
])
param environment string = 'prod'

@description('List of allowed CORS origins for the static assets. Use ["*"] to allow all origins.')
param allowedOrigins array = [
  '*'
]

@description('Index document name for static website hosting.')
param indexDocument string = 'index.html'

@description('Error document path for static website hosting.')
param errorDocument404Path string = '404.html'

@description('Resource tags applied to all resources.')
param tags object = {
  environment: environment
  workload: 'static-assets'
  managedBy: 'bicep'
}

var blobServiceName = 'default'

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
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
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
    dnsEndpointType: 'Standard'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: blobServiceName
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
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    isVersioningEnabled: true
    changeFeed: {
      enabled: true
      retentionInDays: 30
    }
    restorePolicy: {
      enabled: true
      days: 29
    }
  }
}

resource staticWebsite 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: '$web'
  properties: {
    publicAccess: 'None'
    metadata: {
      indexDocument: indexDocument
      errorDocument404Path: errorDocument404Path
    }
  }
}

resource assetsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'assets'
  properties: {
    publicAccess: 'Blob'
    metadata: {
      purpose: 'static-application-assets'
    }
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output primaryWebEndpoint string = storageAccount.properties.primaryEndpoints.web
output assetsContainerName string = assetsContainer.name
output staticWebsiteContainerName string = staticWebsite.name