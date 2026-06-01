param namePrefix string = 'assets'
param storageAccountName string = toLower(take(replace('${namePrefix}${uniqueString(subscription().subscriptionId, resourceGroup().id)}','-',''), 24))
param location string = resourceGroup().location
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param skuName string = 'Standard_GRS'
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'
@allowed([
  'TLS1_2'
])
param minimumTlsVersion string = 'TLS1_2'

param enableStaticWebsite bool = true
param indexDocument string = 'index.html'
param errorDocument404Path string = '404.html'

param allowBlobPublicAccess bool = true
param allowSharedKeyAccess bool = false
param enableVersioning bool = true
@minValue(1)
@maxValue(365)
param deleteRetentionDays int = 7
@minValue(1)
@maxValue(365)
param containerDeleteRetentionDays int = 7

param advancedThreatProtectionEnabled bool = true
param logAnalyticsWorkspaceId string = ''
param uploadPrincipalId string = ''
param tags object = {}

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: publicNetworkAccess
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
      }
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: '${sa.name}/default'
  properties: {
    deleteRetentionPolicy: {
      enabled: deleteRetentionDays > 0
      days: deleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: containerDeleteRetentionDays > 0
      days: containerDeleteRetentionDays
    }
    isVersioningEnabled: enableVersioning
    cors: {
      corsRules: []
    }
    staticWebsite: enableStaticWebsite ? {
      enabled: true
      indexDocument: indexDocument
      errorDocument404Path: errorDocument404Path
    } : {
      enabled: false
    }
  }
}

resource diags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  name: 'storageAccountDiagnostics'
  scope: sa
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

resource atp 'Microsoft.Security/advancedThreatProtection@2019-01-01' = {
  name: 'current'
  scope: sa
  properties: {
    isEnabled: advancedThreatProtectionEnabled
  }
}

resource uploadRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (uploadPrincipalId != '') {
  name: guid(sa.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', uploadPrincipalId)
  scope: sa
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: uploadPrincipalId
  }
}

output storageAccountResourceId string = sa.id
output storageAccountNameOut string = sa.name
output staticWebsitePrimaryEndpoint string = enableStaticWebsite ? sa.properties.primaryEndpoints.web : ''