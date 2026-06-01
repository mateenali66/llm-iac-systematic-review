param accountName string
@description('Primary write region for the Cosmos DB account.')
param primaryLocation string = resourceGroup().location
@description('List of additional read regions. The order determines failover priority starting from 1.')
param readLocations array = []

@allowed([
  'Strong'
  'BoundedStaleness'
  'Session'
  'ConsistentPrefix'
  'Eventual'
])
param consistencyLevel string = 'Session'
@description('Used only when consistencyLevel is BoundedStaleness.')
param maxStalenessPrefix int = 100000
@description('Used only when consistencyLevel is BoundedStaleness.')
param maxIntervalInSeconds int = 5

@description('Enable multiple write regions. Set false for single-region writes.')
param enableMultipleWriteLocations bool = false
@description('Enable automatic failover across regions.')
param enableAutomaticFailover bool = true

@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Enable VNet service endpoint filtering. When true, provide virtualNetworkSubnetIds.')
param isVirtualNetworkFilterEnabled bool = false
@description('Subnet resource IDs with Microsoft.AzureCosmos service endpoints enabled.')
param virtualNetworkSubnetIds array = []
@description('IP ranges allowed to access the account. Example: ["10.0.0.0/24","203.0.113.10"].')
param ipRules array = []

@description('Enable the Azure Cosmos DB free tier (only one free tier account per subscription).')
param enableFreeTier bool = false
@description('Enable analytical store for SQL API.')
param enableAnalyticalStorage bool = false
@description('Disable local authentication (key-based auth). If true, use Azure AD RBAC.')
param disableLocalAuth bool = false
@description('Disallow key-based metadata write operations for enhanced security.')
param disableKeyBasedMetadataWriteAccess bool = true

@allowed([
  'Continuous'
  'Periodic'
])
param backupPolicyType string = 'Continuous'
@allowed([
  'Continuous7Days'
  'Continuous30Days'
])
param continuousTier string = 'Continuous30Days'
@description('Periodic backup interval in minutes (for Periodic backup).')
param backupIntervalInMinutes int = 240
@description('Periodic backup retention in hours (for Periodic backup).')
param backupRetentionInHours int = 720
@allowed([
  'Geo'
  'Local'
  'Zone'
])
@description('Backup storage redundancy (for Periodic backup).')
param backupStorageRedundancy string = 'Geo'

@description('Enable zone redundancy for all regions where supported.')
param enableZoneRedundancy bool = false

param tags object = {}

@description('Resource ID of a Log Analytics workspace for diagnostic logs/metrics. Leave empty to skip.')
param diagnosticLogAnalyticsWorkspaceId string = ''

var additionalLocations = [for (loc, i) in readLocations: {
  locationName: loc
  failoverPriority: i + 1
  isZoneRedundant: enableZoneRedundancy
}]
var locations = concat([
  {
    locationName: primaryLocation
    failoverPriority: 0
    isZoneRedundant: enableZoneRedundancy
  }
], additionalLocations)

var ipRulesObjects = [for ip in ipRules: {
  ipAddressOrRange: ip
}]

var vnetRulesObjects = [for id in virtualNetworkSubnetIds: {
  id: id
  ignoreMissingVNetServiceEndpoint: false
}]

resource account 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: accountName
  location: primaryLocation
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: locations
    enableAutomaticFailover: enableAutomaticFailover
    enableMultipleWriteLocations: enableMultipleWriteLocations
    publicNetworkAccess: publicNetworkAccess
    isVirtualNetworkFilterEnabled: isVirtualNetworkFilterEnabled
    virtualNetworkRules: isVirtualNetworkFilterEnabled && length(virtualNetworkSubnetIds) > 0 ? vnetRulesObjects : []
    ipRules: length(ipRules) > 0 ? ipRulesObjects : []
    disableKeyBasedMetadataWriteAccess: disableKeyBasedMetadataWriteAccess
    enableAnalyticalStorage: enableAnalyticalStorage
    enableFreeTier: enableFreeTier
    disableLocalAuth: disableLocalAuth
    consistencyPolicy: consistencyLevel == 'BoundedStaleness' ? {
      defaultConsistencyLevel: 'BoundedStaleness'
      maxIntervalInSeconds: maxIntervalInSeconds
      maxStalenessPrefix: maxStalenessPrefix
    } : {
      defaultConsistencyLevel: consistencyLevel
    }
    backupPolicy: backupPolicyType == 'Continuous' ? {
      type: 'Continuous'
      continuousModeProperties: {
        tier: continuousTier
      }
    } : {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: backupIntervalInMinutes
        backupRetentionIntervalInHours: backupRetentionInHours
        backupStorageRedundancy: backupStorageRedundancy
      }
    }
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticLogAnalyticsWorkspaceId != '') {
  name: 'cosmosdb-diag'
  scope: account
  properties: {
    workspaceId: diagnosticLogAnalyticsWorkspaceId
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'PartitionKeyStatistics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'ControlPlaneRequests'
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

output cosmosDbAccountId string = account.id
output cosmosDbEndpoint string = account.properties.documentEndpoint
output writeRegion string = primaryLocation
output readRegions array = readLocations