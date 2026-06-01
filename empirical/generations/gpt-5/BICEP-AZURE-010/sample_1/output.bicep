param location string = resourceGroup().location
@description('Globally unique, lowercase Storage Account name (3-24 chars).')
param storageAccountName string = toLower('st' + uniqueString(resourceGroup().id))
@description('CDN Profile name.')
param cdnProfileName string = 'cdn-' + uniqueString(resourceGroup().id)
@description('CDN Endpoint name.')
param cdnEndpointName string = 'cdn-endpoint-' + uniqueString(resourceGroup().id)
@description('Resource tags.')
param tags object = {
  environment: 'prod'
  workload: 'storage-cdn'
}

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
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
    }
    accessTier: 'Hot'
  }
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: '${sa.name}/default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource uploads 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${sa.name}/default/uploads'
  properties: {
    publicAccess: 'Blob'
  }
  dependsOn: [
    blob
  ]
}

resource backups 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${sa.name}/default/backups'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    blob
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
  tags: tags
  properties: {
    isHttpAllowed: false
    isHttpsAllowed: true
    origins: [
      {
        name: 'storage-origin'
        properties: {
          hostName: '${sa.name}.blob.core.windows.net'
          httpPort: 80
          httpsPort: 443
          originHostHeader: '${sa.name}.blob.core.windows.net'
          originPath: '/uploads'
        }
      }
    ]
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'application/javascript'
      'application/json'
      'image/svg+xml'
    ]
    isCompressionEnabled: true
    queryStringCachingBehavior: 'UseQueryString'
  }
  dependsOn: [
    uploads
  ]
}

output storageAccountResourceId string = sa.id
output uploadsContainerUrl string = 'https://${sa.name}.blob.core.windows.net/uploads/'
output backupsContainerUrl string = 'https://${sa.name}.blob.core.windows.net/backups/'
output cdnEndpointHostname string = cdnEndpoint.properties.hostName
output cdnEndpointUrl string = 'https://${cdnEndpoint.properties.hostName}/'