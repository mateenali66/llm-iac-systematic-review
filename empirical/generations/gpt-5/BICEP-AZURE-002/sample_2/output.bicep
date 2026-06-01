param storageAccountName string {
  minLength: 3
  maxLength: 24
  metadata: {
    description: 'Globally unique Storage Account name (lowercase letters and numbers only).'
  }
  regex: '^[a-z0-9]{3,24}$'
}

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param skuName string = 'Standard_GZRS'

@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

param location string = resourceGroup().location

param tags object = {}

param environment string = 'prod'

@allowed([
  'TLS1_2'
])
param minTlsVersion string = 'TLS1_2'

param allowBlobPublicAccess bool = false
param allowSharedKeyAccess bool = false

@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@allowed([
  'Allow'
  'Deny'
])
param networkDefaultAction string = 'Allow'

@description('List of IPv4 address ranges (CIDR) allowed when network default action is Deny.')
param ipRules array = []

@description('List of subnet resource IDs allowed when network default action is Deny.')
param virtualNetworkSubnetResourceIds array = []

@description('Index document for static website.')
param indexDocument string = 'index.html'

@description('404 error document for static website.')
param error404Document string = '404.html'

@minValue(1)
@maxValue(365)
param deleteRetentionDays int = 7

@minValue(1)
@maxValue(365)
param containerDeleteRetentionDays int = 7

@description('Set to true to use a customer-managed key (CMK) from Azure Key Vault.')
param useCmk bool = false

@description('Key Vault URI hosting the CMK (e.g., https://mykv.vault.azure.net/). Required if useCmk is true.')
param cmkKeyVaultUri string = ''

@description('Key name in Key Vault. Required if useCmk is true.')
param cmkKeyName string = ''

@description('Key version in Key Vault. Required if useCmk is true.')
param cmkKeyVersion string = ''

@description('Enable double encryption at rest (infrastructure encryption). Not available in all regions/SKUs.')
param requireInfrastructureEncryption bool = false

@description('Optional Log Analytics Workspace resource ID to send diagnostics.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Optional principal objectId (user, group, or service principal) to grant Storage Blob Data Contributor on this account for publishing assets.')
param assetPublisherPrincipalId string = ''

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
  'ForeignGroup'
  'Device'
  'Application'
  'MSI'
  'DirectoryRoleTemplate'
  'ForeignGroup'
  'DirectoryObjectOrGroup'
  'Unknown'
])
param assetPublisherPrincipalType string = 'ServicePrincipal'

var baseTags = union(tags, {
  environment: environment
})

resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: baseTags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    minimumTlsVersion: minTlsVersion
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: publicNetworkAccess
    networkRuleSet: {
      bypass: 'AzureServices'
      defaultAction: networkDefaultAction
      ipRules: [for ip in ipRules: {
        ipAddressOrRange: ip
        action: 'Allow'
      }]
      virtualNetworkRules: [for subnetId in virtualNetworkSubnetResourceIds: {
        virtualNetworkResourceId: subnetId
        action: 'Allow'
      }]
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
      requireInfrastructureEncryption: requireInfrastructureEncryption
      keySource: useCmk ? 'Microsoft.Keyvault' : 'Microsoft.Storage'
      keyVaultProperties: useCmk ? {
        keyName: cmkKeyName
        keyVersion: cmkKeyVersion
        keyVaultUri: cmkKeyVaultUri
      } : null
    }
    routingPreference: {
      routingChoice: 'MicrosoftRouting'
      publishMicrosoftEndpoints: true
      publishInternetEndpoints: false
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: '${stg.name}/default'
  properties: {
    changeFeed: {
      enabled: false
    }
    deleteRetentionPolicy: {
      enabled: deleteRetentionDays > 0
      days: deleteRetentionDays
    }
    isVersioningEnabled: true
    containerDeleteRetentionPolicy: {
      enabled: containerDeleteRetentionDays > 0
      days: containerDeleteRetentionDays
    }
  }
}

resource staticWebsite 'Microsoft.Storage/storageAccounts/blobServices/staticWebsite@2023-01-01' = {
  name: '${stg.name}/default/default'
  properties: {
    enabled: true
    indexDocument: indexDocument
    error404Document: error404Document
  }
  dependsOn: [
    blobService
  ]
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceResourceId != '') {
  name: '${stg.name}-diag'
  scope: stg
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource publisherRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assetPublisherPrincipalId != '') {
  name: guid(stg.id, storageBlobDataContributorRoleId, assetPublisherPrincipalId)
  scope: stg
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: assetPublisherPrincipalId
    principalType: assetPublisherPrincipalType
  }
}

output storageAccountId string = stg.id
output storageAccountNameOut string = stg.name
output staticWebsiteEndpoint string = stg.properties.primaryEndpoints.web
output blobEndpoint string = stg.properties.primaryEndpoints.blob