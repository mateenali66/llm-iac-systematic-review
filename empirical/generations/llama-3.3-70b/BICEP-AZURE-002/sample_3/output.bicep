param location string = resourceGroup().location
param storageAccountName string = 'staticassets${uniqueString(resourceGroup().id)}'

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
    defaultToOAuthAuthentication: true
    encryption: {
      services: {
        blob: {
          keyType: 'Account'
          enabled: true
        }
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      identity: {
        type: 'SystemAssigned'
      }
    }
  }
}

output storageAccountName string = storageAccountResource.name
output storageAccountId string = storageAccountResource.id