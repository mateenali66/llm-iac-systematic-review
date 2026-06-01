@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Globally unique storage account name (3-24 lowercase alphanumeric).')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('CDN profile name.')
param cdnProfileName string = 'cdn-${uniqueString(resourceGroup().id)}'

@description('CDN endpoint name (must be globally unique).')
param cdnEndpointName string = 'cdne-${uniqueString(resourceGroup().id)}'

@description('Resource tags.')
param tags object = {
  environment: 'production'
  managedBy: 'bicep'
}

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Standard_RAGRS'
  'Standard_GZRS'
])
param storageSkuName string = 'Standard_GRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
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
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
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
    }
  }
}

resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'uploads'
  properties: {
    publicAccess: 'Blob'
    metadata: {
      purpose: 'public-uploads-for-cdn'
    }
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'backups'
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'private-backups'
    }
  }
}

resource cdnProfile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: cdnProfileName
  location: 'global'
  tags: tags
  sku: {
    name: 'Standard_Microsoft'
  }
  properties: {}
}

var storageBlobHost = replace(replace(storageAccount.properties.primaryEndpoints.blob, 'https://', ''), '/', '')

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2024-02-01' = {
  parent: cdnProfile
  name: cdnEndpointName
  location: 'global'
  tags: tags
  properties: {
    originHostHeader: storageBlobHost
    isHttpAllowed: false
    isHttpsAllowed: true
    isCompressionEnabled: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    contentTypesToCompress: [
      'application/javascript'
      'application/json'
      'application/xml'
      'image/svg+xml'
      'text/css'
      'text/html'
      'text/javascript'
      'text/plain'
    ]
    origins: [
      {
        name: 'storage-origin'
        properties: {
          hostName: storageBlobHost
          httpsPort: 443
          originHostHeader: storageBlobHost
          priority: 1
          weight: 1000
          enabled: true
        }
      }
    ]
    originPath: '/uploads'
    deliveryPolicy: {
      description: 'Restrict CDN to uploads container only'
      rules: [
        {
          name: 'EnforceHttps'
          order: 1
          conditions: [
            {
              name: 'RequestScheme'
              parameters: {
                typeName: 'DeliveryRuleRequestSchemeConditionParameters'
                matchValues: [
                  'HTTP'
                ]
                operator: 'Equal'
                negateCondition: false
              }
            }
          ]
          actions: [
            {
              name: 'UrlRedirect'
              parameters: {
                typeName: 'DeliveryRuleUrlRedirectActionParameters'
                redirectType: 'Found'
                destinationProtocol: 'Https'
              }
            }
          ]
        }
      ]
    }
  }
}

@description('Grant the CDN endpoint Storage Blob Data Reader on the uploads container scope (defense-in-depth; container is also public blob).')
resource cdnBlobReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(uploadsContainer.id, cdnEndpoint.id, 'StorageBlobD