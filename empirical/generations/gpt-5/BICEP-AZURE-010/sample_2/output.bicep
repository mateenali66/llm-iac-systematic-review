param location string = resourceGroup().location
param baseName string = 'app'
param tags object = {}

var storageAccountName = toLower('st${uniqueString(resourceGroup().id, baseName)}')
var cdnProfileName = toLower('cdn-${uniqueString(resourceGroup().id, baseName)}')
var cdnEndpointName = toLower('cdn-endp-${uniqueString(resourceGroup().id, baseName)}')
var originHostName = '${storageAccountName}.blob.${environment().suffixes.storage}'

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
    minimumTlsVersion: 'TLS1_2'
    accessTier: 'Hot'
    publicNetworkAccess: 'Enabled'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: '${sa.name}/default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    changeFeed: {
      enabled: true
    }
    isVersioningEnabled: true
  }
}

resource uploads 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${sa.name}/default/uploads'
  properties: {
    publicAccess: 'Blob'
  }
  dependsOn: [
    blobService
  ]
}

resource backups 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${sa.name}/default/backups'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    blobService
  ]
}

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: cdnProfileName
  location: 'global'
  sku: {
    name: 'Standard_Microsoft'
  }
  tags: tags
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  name: '${cdnProfile.name}/${cdnEndpointName}'
  location: 'global'
  properties: {
    originPath: '/uploads'
    isHttpAllowed: false
    isHttpsAllowed: true
    isCompressionEnabled: true
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'application/javascript'
      'application/x-javascript'
      'text/javascript'
      'application/json'
      'application/xml'
      'image/svg+xml'
    ]
    queryStringCachingBehavior: 'UseQueryString'
    originHostHeader: originHostName
    origins: [
      {
        name: 'storage-origin'
        properties: {
          hostName: originHostName
          httpPort: 80
          httpsPort: 443
          priority: 1
          weight: 50
        }
      }
    ]
  }
  dependsOn: [
    uploads
  ]
}