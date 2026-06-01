param location string = resourceGroup().location
param storageAccountName string = uniqueString(resourceGroup().id)
param cdnProfileName string = 'cdn-profile-${uniqueString(resourceGroup().id)}'
param cdnEndpointName string = 'cdn-endpoint-${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'uploads'
  parent: storageAccount::blobServicesDefault
  properties: {
    publicAccess: 'Container'
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'backups'
  parent: storageAccount::blobServicesDefault
  properties: {
    publicAccess: 'None'
  }
}

resource blobServicesDefault 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: cdnProfileName
  location: 'global'
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  name: cdnEndpointName
  parent: cdnProfile
  location: 'global'
  properties: {
    originHostHeader: storageAccount.properties.primaryEndpoints.blob
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    origins: [
      {
        name: 'storageOrigin'
        properties: {
          hostName: replace(replace(storageAccount.properties.primaryEndpoints.blob, 'https://', ''), '/', '')
          httpPort: 80
          httpsPort: 443
        }
      }
    ]
    deliveryPolicy: {
      rules: [
        {
          name: 'AllowUploadsContainer'
          order: 1
          conditions: {
            urlPathCondition: {
              operator: 'BeginsWith'
              matchValues: [
                '/uploads/'
              ]
            }
          }
          actions: {
            cacheExpirationAction: {
              behavior: 'SetIfMissing'
              cacheDuration: '00:00:00'
            }
          }
        }
      ]
    }
  }
}