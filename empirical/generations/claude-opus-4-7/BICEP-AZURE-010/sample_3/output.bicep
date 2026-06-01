@description('Location for all resources.')
param location string = resourceGroup().location

@description('Globally unique name for the storage account (3-24 lowercase alphanumeric).')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('Storage account SKU.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Standard_GZRS'
])
param storageSkuName string = 'Standard_LRS'

@description('CDN profile name.')
param cdnProfileName string = 'cdn-${uniqueString(resourceGroup().id)}'

@description('CDN endpoint name (must be globally unique).')
param cdnEndpointName string = 'cdne-${uniqueString(resourceGroup().id)}'

@description('CDN SKU.')
@allowed([
  'Standard_Microsoft'
  'Standard_Akamai'
  'Standard_Verizon'
  'Premium_Verizon'
])
param cdnSkuName string = 'Standard_Microsoft'

@description('Resource tags.')
param tags object = {
  environment: 'production'
  managedBy: 'bicep'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
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
  name: 'uploads'
  properties: {
    publicAccess: 'Blob'
    metadata: {
      purpose: 'cdn-readable-uploads'
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

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: cdnProfileName
  location: 'global'
  tags: tags
  sku: {
    name: cdnSkuName
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  parent: cdnProfile
  name: cdnEndpointName
  location: 'global'
  tags: tags
  properties: {
    originHostHeader: replace(replace(storageAccount.properties.primaryEndpoints.blob, 'https://', ''), '/', '')
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    isCompressionEnabled: true
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'application/javascript'
      'application/json'
      'image/svg+xml'
    ]
    origins: [
      {
        name: 'storage-origin'
        properties: {
          hostName: replace(replace(storageAccount.properties.primaryEndpoints.blob, 'https://', ''), '/', '')
          httpsPort: 443
          originHostHeader: replace(replace(storageAccount.properties.primaryEndpoints.blob, 'https://', ''), '/', '')
          priority: 1
          weight: 1000
          enabled: true
        }
      }
    ]
    deliveryPolicy: {
      description: 'Restrict CDN to the uploads container only'
      rules: [
        {
          name: 'AllowUploadsOnly'
          order: 1
          conditions: [
            {
              name: 'UrlPath'
              parameters: {
                typeName: 'DeliveryRuleUrlPathMatchConditionParameters'
                operator: 'BeginsWith'
                negateCondition: true
                matchValues: [
                  '/uploads/'
                ]
                transforms: [
                  'Lowercase'
                ]
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
                customPath: '/uploads/'
              }
            }
          ]
        }
        {
          name: 'EnforceHttps'
          order: 2
          conditions: [