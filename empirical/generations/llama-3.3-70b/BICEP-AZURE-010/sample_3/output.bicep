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
    publicAccess: 'Container'
    metadata: {}
  }
  dependsOn: [
    storageAccountResource
  ]
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: '${storageAccountName}/default/backups'
  properties: {
    publicAccess: 'None'
    metadata: {}
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
      name: 'Standard_Akamai'
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
    ]
  }
  dependsOn: [
    cdnProfile
  ]
}

resource cdnEndpointOrigin 'Microsoft.Cdn/profiles/endpoints/origins@2021-06-01' = {
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

resource cdnCustomDomain 'Microsoft.Cdn/profiles/endpoints/customDomains@2021-06-01' = {
  name: '${cdnProfileName}/${cdnEndpointName}/${cdnEndpointName}'
  properties: {
    hostName: '${cdnEndpointName}.azureedge.net'
  }
  dependsOn: [
    cdnEndpoint
  ]
}

output storageAccountName string = storageAccountName
output uploadsContainerName string = 'uploads'
output backupsContainerName string = 'backups'
output cdnEndpointUrl string = 'https://${cdnEndpointName}.azureedge.net'