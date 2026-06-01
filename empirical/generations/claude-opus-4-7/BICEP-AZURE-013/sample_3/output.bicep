@description('The name of the Cosmos DB account. Must be globally unique, lowercase, and 3-44 characters.')
@minLength(3)
@maxLength(44)
param accountName string = 'cosmos-${uniqueString(resourceGroup().id)}'

@description('The primary write region for the Cosmos DB account.')
param primaryRegion string = resourceGroup().location

@description('Additional read regions for global distribution.')
param readRegions array = [
  'westeurope'
  'southeastasia'
]

@description('The default consistency level of the Cosmos DB account.')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'

@description('Max stale requests. Required for BoundedStaleness. Valid ranges: 10-2147483647 for single-region, 100000-2147483647 for multi-region.')
@minValue(10)
@maxValue(2147483647)
param maxStalenessPrefix int = 100000

@description('Max lag time (seconds). Required for BoundedStaleness. Valid ranges: 5-86400 for single-region, 300-86400 for multi-region.')
@minValue(5)
@maxValue(86400)
param maxIntervalInSeconds int = 300

@description('Enable automatic failover for regions.')
param automaticFailover bool = true

@description('Enable multi-region writes. Set to false for single-region writes initially.')
param multipleWriteLocations bool = false

@description('Enable zone redundancy for the primary region.')
param enableZoneRedundancy bool = true

@description('Enable free tier (only one per subscription).')
param enableFreeTier bool = false

@description('The name of the SQL database.')
param databaseName string = 'appdb'

@description('The name of the container.')
param containerName string = 'items'

@description('The partition key path for the container.')
param partitionKeyPath string = '/id'

@description('Throughput (RU/s) for autoscale max. Min 1000.')
@minValue(1000)
@maxValue(1000000)
param autoscaleMaxThroughput int = 4000

@description('Backup policy type.')
@allowed([
  'Continuous'
  'Periodic'
])
param backupPolicyType string = 'Continuous'

@description('Tags to apply to all resources.')
param tags object = {
  environment: 'production'
  workload: 'cosmos-sql'
}

var consistencyPolicy = {
  Eventual: {
    defaultConsistencyLevel: 'Eventual'
  }
  ConsistentPrefix: {
    defaultConsistencyLevel: 'ConsistentPrefix'
  }
  Session: {
    defaultConsistencyLevel: 'Session'
  }
  BoundedStaleness: {
    defaultConsistencyLevel: 'BoundedStaleness'
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
  }
  Strong: {
    defaultConsistencyLevel: 'Strong'
  }
}

var primaryLocation = [
  {
    locationName: primaryRegion
    failoverPriority: 0
    isZoneRedundant: enableZoneRedundancy
  }
]

var additionalLocations = [for (region, i) in readRegions: {
  locationName: region
  failoverPriority: i + 1
  isZoneRedundant: false
}]

var locations = concat(primaryLocation, additionalLocations)

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: toLower(accountName)
  location: primaryRegion
  tags: tags
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
    locations: locations
    enableAutomaticFailover: automaticFailover
    enableMultipleWriteLocations: multipleWriteLocations
    enableFreeTier: enableFreeTier
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    disableKeyBasedMetadataWriteAccess: true
    minimalTlsVersion: 'Tls12'
    isVirtualNetworkFilterEnabled: false
    networkAclBypass: 'AzureServices'
    backupPolicy: backupPolicyType == 'Continuous' ? {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous30Days'
      }
    } : {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 168
        backupStorageRedundancy: 'Geo'
      }
    }
    capabilities: []
    apiProperties: {}
    ipRules: []
  }
}

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource sqlContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: sqlDatabase
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          partitionKeyPath
        ]
        kind: 'Hash'
        version: 2
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }