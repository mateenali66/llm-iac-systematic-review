param location string = resourceGroup().location
param storageAccountName string
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageSkuName string = 'Standard_GRS'
param cdnProfileName string
param cdnEndpointName string

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
    }
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
    isVersioningEnabled: true
    changeFeed: {
      enabled: true
    }
    cors: {
      corsRules: []
    }
    defaultServiceVersion: '2020-10-02'
  }
}

resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${sa.name}/default/uploads'
  properties: {
    publicAccess: 'Blob'
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${sa.name}/default/backups'
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
  name: '${cdnProfile.name}/${cdnEndpointName}'
  location: 'global'
  properties: {
    isHttpAllowed: false
    isHttpsAllowed: true
    originHostHeader: '${sa.name}.blob.core.windows.net'
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'application/javascript'
      'application/json'
      'application/xml'
      'text/xml'
      'image/svg+xml'
    ]
    isCompressionEnabled: true
    queryStringCachingBehavior: 'UseQueryString'
  }
}

resource cdnOrigin 'Microsoft.Cdn/profiles/endpoints/origins@2023-05-01' = {
  name: '${cdnEndpoint.name}/storage-origin'
  properties: {
    hostName: '${sa.name}.blob.core.windows.net'
    originPath: '/uploads'
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 1000
  }
  dependsOn: [
    uploadsContainer
  ]
}

output storageAccountId string = sa.id
output uploadsContainerUrl string = 'https://${sa.name}.blob.core.windows.net/uploads/'
output cdnEndpointHost string = '${cdnEndpointName}.azureedge.net'