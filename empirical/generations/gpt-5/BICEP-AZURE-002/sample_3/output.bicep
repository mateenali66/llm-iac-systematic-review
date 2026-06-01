param storageAccountName string
@description('Location for all resources.')
param location string = resourceGroup().location
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
@description('Redundancy SKU for the Storage Account.')
param skuName string = 'Standard_ZRS'
@description('Enable blob versioning for safer rollbacks of static assets.')
param enableVersioning bool = true
@minValue(1)
@maxValue(365)
@description('Number of days to retain soft-deleted blobs.')
param blobSoftDeleteDays int = 14
@allowed([
  'TLS1_2'
  'TLS1_1'
  'TLS1_0'
])
@description('Minimum TLS version enforced by the Storage Account.')
param minimumTlsVersion string = 'TLS1_2'
@description('Disallow Shared Key authorization; prefer Azure AD for uploads.')
param allowSharedKeyAccess bool = false
@description('Apply resource tags.')
param tags object = {}
@description('Static website index document.')
param indexDocument string = 'index.html'
@description('Static website 404 error document path.')
param errorDocumentPath string = '404.html'
@allowed([
  'Allow'
  'Deny'
])
@description('Default network action. Use Allow for publicly accessible static website.')
param networkDefaultAction string = 'Allow'
@allowed([
  'None'
  'AzureServices'
  'Logging'
  'Metrics'
  'AzureServices,Logging,Metrics'
])
@description('Bypass traffic for selected Azure services.')
param networkBypass string = 'AzureServices'
@description('Optional list of public IP/CIDR rules allowed to access the account when using network rules.')
param ipRules array = []
@description('Optional list of subnet resource IDs allowed to access the account when using network rules.')
param virtualNetworkSubnetIds array = []
@description('Enable public network access to serve the static site.')
param allowPublicNetworkAccess bool = true
@description('Optional RBAC assignments on the Storage Account. Each item: { principalId: string, roleDefinitionId?: string }')
param rbacAssignments array = []

var defaultBlobContributorRoleGuid = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: allowSharedKeyAccess
    minimumTlsVersion: minimumTlsVersion
    publicNetworkAccess: allowPublicNetworkAccess ? 'Enabled' : 'Disabled'
    supportsHttpsTrafficOnly: true
    networkRuleSet: {
      bypass: networkBypass
      defaultAction: networkDefaultAction
      ipRules: [for ip in ipRules: {
        action: 'Allow'
        value: ip
      }]
      virtualNetworkRules: [for s in virtualNetworkSubnetIds: {
        action: 'Allow'
        id: s
      }]
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: '${sa.name}/default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: blobSoftDeleteDays
    }
    isVersioningEnabled: enableVersioning
    changeFeed: {
      enabled: true
    }
    cors: {
      corsRules: []
    }
    defaultServiceVersion: '2020-06-12'
    restorePolicy: {
      enabled: false
    }
    staticWebsite: {
      enabled: true
      indexDocument: indexDocument
      errorDocument404Path: errorDocumentPath
    }
  }
}

resource rbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for ra in rbacAssignments: {
  name: guid(sa.id, ra.principalId, empty(ra.roleDefinitionId) ? defaultBlobContributorRoleGuid : ra.roleDefinitionId)
  scope: sa
  properties: {
    principalId: ra.principalId
    roleDefinitionId: empty(ra.roleDefinitionId)
      ? subscriptionResourceId('Microsoft.Authorization/roleDefinitions', defaultBlobContributorRoleGuid)
      : (contains(ra.roleDefinitionId, '/')
          ? ra.roleDefinitionId
          : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ra.roleDefinitionId))
  }
}]

@description('Storage Account resource ID.')
output storageAccountResourceId string = sa.id
@description('Static website primary endpoint URL.')
output staticWebsitePrimaryEndpoint string = sa.properties.primaryEndpoints.web
@description('Primary blob endpoint URL.')
output primaryBlobEndpoint string = sa.properties.primaryEndpoints.blob