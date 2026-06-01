param location string = resourceGroup().location
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'
param cdnProfileName string = 'cdnp-${storageAccountName}'
param cdnEndpointName string = 'cdne-${storageAccountName}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    supportsHttpsTrafficOnly: true
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
  }
}

resource cdnEndpointCustomDomain 'Microsoft.Cdn/profiles/endpoints/customDomains@2023-05-01' = {
  parent: cdnEndpoint
  name: '${cdnEndpointName}-cdn'
  properties: {
    hostName: cdnEndpoint.properties.hostName
  }
}

// Grant CDN access to uploads container via managed identity
resource cdnIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${cdnProfileName}-identity'
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, cdnIdentity.id, 'Storage Blob Data Reader')
  scope: storageAccount
  properties: {
    principalId: cdnIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader
    principalType: 'ServicePrincipal'
  }
}