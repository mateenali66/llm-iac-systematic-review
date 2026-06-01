param location string = resourceGroup().location
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'
param cdnProfileName string = 'cdn-${storageAccountName}'
param cdnEndpointName string = 'cdnendpoint-${storageAccountName}'

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
  name: '${storageAccountName}/default/uploads'
  properties: {
    publicAccess: 'None'
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccountName}/default/backups'
  properties: {
    publicAccess: 'None'
  }
}

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: cdnProfileName
  location: 'global'
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  parent: cdnProfile
  name: cdnEndpointName
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
              negateCondition: false
              transforms: []
            }
          }
          actions: [
            {
              name: 'CacheExpiration'
              parameters: {
                cacheBehavior: 'SetIfMissing'
                cacheDuration: '00:00:00'
                cacheType: 'All'
              }
            }
          ]
        }
      ]
    }
  }
}

output storageAccountName string = storageAccountName
output storageAccountBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output cdnEndpointHostname string = cdnEndpoint.properties.hostName