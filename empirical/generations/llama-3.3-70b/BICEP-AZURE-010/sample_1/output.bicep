param location string = resourceGroup().location
param storageAccountName string = 'storage${uniqueString(resourceGroup().id)}'
param cdnProfileName string = 'cdn${uniqueString(resourceGroup().id)}'
param cdnEndpointName string = 'endpoint${uniqueString(resourceGroup().id)}'

resource storageAccountResource 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    enableHttpsTrafficOnly: true
  }
}

resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: '${storageAccountName}/default/uploads'
  properties: {
    publicAccess: 'Blob'
    defaultEncryptionScope: 'Microsoft.Management/encryptionScopes/default'
    denyEncryptionScopeOverride: false
  }
  dependsOn: [
    storageAccountResource
  ]
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: '${storageAccountName}/default/backups'
  properties: {
    publicAccess: 'None'
    defaultEncryptionScope: 'Microsoft.Management/encryptionScopes/default'
    denyEncryptionScopeOverride: false
  }
  dependsOn: [
    storageAccountResource
  ]
}

resource cdnProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: cdnProfileName
  location: location
  properties: {
    sku: {
      name: 'Standard_Verizon'
    }
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2021-06-01' = {
  name: '${cdnProfileName}/${cdnEndpointName}'
  properties: {
    originHostHeader: storageAccountName
    origins: [
      {
        name: 'storageOrigin'
        properties: {
          hostName: '${storageAccountName}.blob.core.windows.net'
          httpPort: 80
          httpsPort: 443
        }
      }
    ]
    contentTypesToCompress: [
      'text/plain'
      'text/css'
      'application/javascript'
      'text/html'
      'application/xml'
      'text/javascript'
      'application/json'
      'text/json'
    ]
  }
  dependsOn: [
    cdnProfile
  ]
}

resource cdnOrigin 'Microsoft.Cdn/profiles/endpoints/origins@2021-06-01' = {
  name: '${cdnProfileName}/${cdnEndpointName}/storageOrigin'
  properties: {
    hostName: '${storageAccountName}.blob.core.windows.net'
    httpPort: 80
    httpsPort: 443
  }
  dependsOn: [
    cdnEndpoint
  ]
}

resource cdnRoute 'Microsoft.Cdn/profiles/endpoints/routes@2021-06-01' = {
  name: '${cdnProfileName}/${cdnEndpointName}/default'
  properties: {
    originGroup: {
      id: cdnOrigin.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
  }
  dependsOn: [
    cdnEndpoint
  ]
}