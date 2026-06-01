param name string
@description('Primary write region for the Cosmos DB account')
param primaryLocation string = resourceGroup().location
@description('Additional read regions for global distribution. Order defines failover priority.')
param additionalReadLocations array = []
@allowed([
  'Enabled'
  'Disabled'
])
@description('Controls public network access to the account. Disabled by default for production.')
param publicNetworkAccess string = 'Disabled'
@description('Allowed public IP ranges (CIDR notation) when public network access is enabled.')
param allowedIpRanges array = []
@description('Enable virtual network firewall rules for the public endpoint.')
param isVirtualNetworkFilterEnabled bool = false
@description('Subnet resource IDs with Service Endpoints for Microsoft.AzureCosmosDB.')
param virtualNetworkSubnetIds array = []
@allowed([
  'Tls'
  'Tls11'
  'Tls12'
])
@description('Minimum TLS version enforced by the account.')
param minimalTlsVersion string = 'Tls12'
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
@description('Consistency level for the account.')
param defaultConsistencyLevel string = 'Session'
@description('Max staleness prefix for BoundedStaleness.')
param maxStalenessPrefix int = 100000
@description('Max interval in seconds for BoundedStaleness.')
param maxIntervalInSeconds int = 300
@description('Enable analytical storage for HTAP workloads.')
param enableAnalyticalStorage bool = false
@description('Enable automatic failover across regions (effective when multiple regions are configured).')
param enableAutomaticFailover bool = true
@description('Enable multiple write regions (multi-master). Keep disabled for single-region writes initially.')
param enableMultipleWriteLocations bool = false
@description('Enable zone redundancy for regions that support it.')
param enableZoneRedundancy bool = false
@description('Enable Azure Cosmos DB Free Tier.')
param freeTierEnabled bool = false
@description('Disables key-based writes of metadata to enhance security.')
param disableKeyBasedMetadataWriteAccess bool = true
@allowed([
  'None'
  'AzureServices'
])
@description('Bypass option for network ACLs.')
param networkAclBypass string = 'None'
@description('Resource IDs permitted to bypass network ACLs when networkAclBypass is AzureServices.')
param networkAclBypassResourceIds array = []
@description('Optional Key Vault key URI to enable Customer-Managed Key (CMK) encryption.')
param keyVaultKeyUri string = ''
@allowed([
  'Continuous'
  'Periodic'
])
@description('Backup policy type. Continuous recommended for production.')
param backupType string = 'Continuous'
@allowed([
  'Continuous7Days'
  'Continuous30Days'
])
@description('Continuous backup data retention tier.')
param continuousBackupTier string = 'Continuous7Days'
@description('Periodic backup interval in minutes (only when backupType = Periodic).')
param periodicBackupIntervalInMinutes int = 240
@description('Periodic backup retention in hours (only when backupType = Periodic).')
param periodicBackupRetentionInHours int = 720
@allowed([
  'Local'
  'Zone'
  'Geo'
])
@description('Storage redundancy for periodic backup (only when backupType = Periodic).')
param periodicBackupStorageRedundancy string = 'Geo'
@description('Resource tags.')
param tags object = {}
@description('Optional Log Analytics workspace resource ID for diagnostic logs and metrics.')
param logAnalyticsWorkspaceId string = ''

var isContinuous = backupType == 'Continuous'
var locationsArray = [
  {
    locationName: primaryLocation
    failoverPriority: 0
    isZoneRedundant: enableZoneRedundancy
  }
  for (loc, i) in additionalReadLocations: {
    locationName: loc
    failoverPriority: i + 1
    isZoneRedundant: enableZoneRedundancy
  }
]
var ipRulesObjects = [for ip in allowedIpRanges: { ipAddressOrRange: ip }]
var vnetRulesObjects = [for id in virtualNetworkSubnetIds: {
  id: id
  ignoreMissingVNetServiceEndpoint: false
}]
var consistencyPolicy = defaultConsistencyLevel == 'BoundedStaleness'
  ? {
      defaultConsistencyLevel: defaultConsistencyLevel
      maxIntervalInSeconds: maxIntervalInSeconds
      maxStalenessPrefix: maxStalenessPrefix
    }
  : {
      defaultConsistencyLevel: defaultConsistencyLevel
    }
var backupPolicy = isContinuous
  ? {
      type: 'Continuous'
      continuousModeProperties: {
        tier: continuousBackupTier
      }
    }
  : {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: periodicBackupIntervalInMinutes
        backupRetentionIntervalInHours: periodicBackupRetentionInHours
        backupStorageRedundancy: periodicBackupStorageRedundancy
      }
    }
var baseProperties = {
  consistencyPolicy: consistencyPolicy
  locations: locationsArray
  enableAutomaticFailover: enableAutomaticFailover
  enableMultipleWriteLocations: enableMultipleWriteLocations
  minimalTlsVersion: minimalTlsVersion
  publicNetworkAccess: publicNetworkAccess
  isVirtualNetworkFilterEnabled: isVirtualNetworkFilterEnabled
  virtualNetworkRules: vnetRulesObjects
  ipRules: ipRulesObjects
  enableAnalyticalStorage: enableAnalyticalStorage
  disableKeyBasedMetadataWriteAccess: disableKeyBasedMetadataWriteAccess
  enableFreeTier: freeTierEnabled
  backupPolicy: backupPolicy
  networkAclBypass: networkAclBypass
  networkAclBypassResourceIds: networkAclBypass == 'AzureServices' ? networkAclBypassResourceIds : []
}
var cmkProperties = empty(keyVaultKeyUri) ? {} : { keyVaultKeyUri: keyVaultKeyUri }
var accountProperties = union(baseProperties, cmkProperties)

resource account 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: name
  location: primaryLocation
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: accountProperties
  tags: tags
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diag'
  scope: account
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'ControlPlaneRequests'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
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