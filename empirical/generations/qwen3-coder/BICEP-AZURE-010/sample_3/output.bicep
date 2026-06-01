param location string = resourceGroup().location
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'
param cdnProfileName string = 'cdn-${storageAccountName}'
param cdnEndpointName string = 'cdn-endpoint-${storageAccountName}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccount.name}/default/uploads'
  properties: {
    publicAccess: 'Blob'
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccount.name}/default/backups'
  properties: {
    publicAccess: 'None'
  }
}

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: cdnProfileName
  location: 'Global'
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  name: cdnEndpointName
  parent: cdnProfile
  location: 'Global'
  properties: {
    originHostHeader: '${storageAccount.name}.blob.core.windows.net'
    origins: [
      {
        name: 'origin1'
        properties: {
          hostName: '${storageAccount.name}.blob.core.windows.net'
          httpPort: 80
          httpsPort: 443
        }
      }
    ]
    deliveryPolicy: {
      rules: []
    }
  }
}

output storageAccountName string = storageAccount.name
output uploadsContainerUrl string = 'https://${storageAccount.name}.blob.core.windows.net/uploads'
output backupsContainerUrl string = 'https://${storageAccount.name}.blob.core.windows.net/backups'
output cdnEndpointUrl string = 'https://${cdnEndpoint.name}.azureedge.net'