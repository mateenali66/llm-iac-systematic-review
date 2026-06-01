param location string = resourceGroup().location
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'
param appDomainName string = ''

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource staticWebsiteContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '$web'
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01-preview' = if (!empty(appDomainName)) {
  name: '${storageAccountName}-cdn'
  location: 'global'
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01-preview' = if (!empty(appDomainName)) {
  name: '${storageAccountName}-endpoint'
  parent: cdnProfile
  location: 'global'
  properties: {
    origins: [
      {
        name: 'storageOrigin'
        properties: {
          hostName: replace(replace(storageAccount.properties.primaryEndpoints.web, 'https://', ''), '/', '')
        }
      }
    ]
    originHostHeader: replace(replace(storageAccount.properties.primaryEndpoints.web, 'https://', ''), '/', '')
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    optimizationType: 'GeneralWebDelivery'
    customDomains: [
      {
        name: appDomainName
        properties: {
          hostName: appDomainName
        }
      }
    ]
  }
}

output storageAccountName string = storageAccount.name
output storageAccountPrimaryEndpoint string = storageAccount.properties.primaryEndpoints.web
output cdnEndpointHostName string = !empty(appDomainName) ? cdnEndpoint.properties.hostName : ''