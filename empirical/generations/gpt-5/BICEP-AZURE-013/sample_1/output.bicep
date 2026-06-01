param cosmosAccountName string
param primaryRegion string
param readRegions array = []
param consistencyLevel string {
  default: 'Session'
  allowed: [
    'Strong'
    'BoundedStaleness'
    'Session'
    'ConsistentPrefix'
    'Eventual'
  ]
}
param maxStalenessPrefix int = 100000
param maxIntervalInSeconds int = 300
param automaticFailover bool = true
param multipleWriteLocations bool = false
param publicNetworkAccess string {
  default: 'Disabled'
  allowed: [
    'Enabled'
    'Disabled'
  ]
}
param isVirtualNetworkFilterEnabled bool = true
param ipRules array = []
param virtualNetworkRuleIds array = []
param ignoreMissingVNetServiceEndpoint bool = false
param networkAclBypass string {
  default: 'None'
  allowed: [
    'None'
    'AzureServices'
  ]
}
param networkAclBypassResourceIds array = []
param minimalTlsVersion string {
  default: 'Tls12'
  allowed: [
    'Tls12'
  ]
}
param disableLocalAuth bool = true
param analyticalStorageEnabled bool = false
param freeTier bool = false
param backupPolicyType string {
  default: 'Continuous'
  allowed: [
    'Periodic'
    'Continuous'
  ]
}
param backupStorageRedundancy string {
  default: 'Geo'
  allowed: [
    'Local'
    'Zone'
    'Geo'
  ]
}
param backupIntervalInMinutes int = 240
param backupRetentionIntervalInHours int = 720
param continuousTier string {
  default: 'Continuous7Days'
  allowed: [
    'Continuous7Days'
    'Continuous30Days'
  ]
}
param zoneRedundant bool = true
param tags object = {}

param privateEndpointSubnetId string = ''
param privateEndpointLocation string = ''
param privateDnsZoneId string = ''

param logAnalyticsWorkspaceId string = ''

var primaryLocation = {
  locationName: primaryRegion
  failoverPriority: 0
  isZoneRedundant: zoneRedundant
}
var readLocationObjects = [for (region, i) in readRegions: {
  locationName: region
  failoverPriority: i + 1
  isZoneRedundant: zoneRedundant
}]
var locationsVar = concat([primaryLocation], readLocationObjects)

var ipRulesObjects = [for ip in ipRules: {
  ipAddressOrRange: ip
}]
var vnetRulesObjects = [for id in virtualNetworkRuleIds: {
  id: id
  ignoreMissingVNetServiceEndpoint: ignoreMissingVNetServiceEndpoint
}]

var vnetFilterEnabled = publicNetworkAccess == 'Enabled' ? isVirtualNetworkFilterEnabled : false

var consistencyPolicyVar = consistencyLevel == 'BoundedStaleness' ? {
  defaultConsistencyLevel: 'BoundedStaleness'
  maxStalenessPrefix: maxStalenessPrefix
  maxIntervalInSeconds: maxIntervalInSeconds
} : {
  defaultConsistencyLevel: consistencyLevel
}

var backupPolicyVar = backupPolicyType == 'Continuous' ? {
  type: 'Continuous'
  continuousModeProperties: {
    tier: continuousTier
  }
} : {
  type: 'Periodic'
  periodicModeProperties: {
    backupIntervalInMinutes: backupIntervalInMinutes
    backupRetentionIntervalInHours: backupRetentionIntervalInHours
    backupStorageRedundancy: backupStorageRedundancy
  }
}

var peLocation = empty(privateEndpointLocation) ? primaryRegion : privateEndpointLocation

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosAccountName
  location: primaryRegion
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    locations: locationsVar
    consistencyPolicy: consistencyPolicyVar
    enableAutomaticFailover: length(locationsVar) > 1 ? automaticFailover : false
    enableMultipleWriteLocations: multipleWriteLocations
    publicNetworkAccess: publicNetworkAccess
    isVirtualNetworkFilterEnabled: vnetFilterEnabled
    ipRules: ipRulesObjects
    virtualNetworkRules: vnetRulesObjects
    networkAclBypass: networkAclBypass
    networkAclBypassResourceIds: networkAclBypassResourceIds
    minimalTlsVersion: minimalTlsVersion
    disableLocalAuth: disableLocalAuth
    enableAnalyticalStorage: analyticalStorageEnabled
    enableFreeTier: freeTier
    backupPolicy: backupPolicyVar
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2023-09-01' = if (!empty(privateEndpointSubnetId)) {
  name: '${cosmos.name}-pe'
  location: peLocation
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'cosmosdb-sql'
        properties: {
          privateLinkServiceId: cosmos.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }
}

resource dnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-05-01' = if (!empty(privateDnsZoneId) && !empty(privateEndpointSubnetId)) {
  name: '${pe.name}/cosmosdb-dns'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmosdb-privatelink-documents'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'cosmosdb-diag'
  scope: cosmos
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
      }
      {
        category: 'ControlPlaneRequests'
        enabled: true
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
      }
      {
        category: 'PartitionKeyStatistics'
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