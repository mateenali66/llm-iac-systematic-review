@description('Cosmos DB account name (must be globally unique, lowercase)')
@minLength(3)
@maxLength(44)
param accountName string = 'cosmos-${uniqueString(resourceGroup().id)}'

@description('Primary write region for the Cosmos DB account')
param primaryRegion string = resourceGroup().location

@description('Additional read regions for global distribution')
param readRegions array = [
  'westeurope'
  'southeastasia'
]

@description('The default consistency level of the Cosmos DB account')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'

@description('Max staleness prefix when using BoundedStaleness')
@minValue(10)
@maxValue(2147483647)
param maxStalenessPrefix int = 100000

@description('Max lag time in seconds when using BoundedStaleness')
@minValue(5)
@maxValue(86400)
param maxIntervalInSeconds int = 300

@description('Enable automatic failover')
param automaticFailover bool = true

@description('Enable zone redundancy on the primary region')
param enableZoneRedundancy bool = true

@description('Enable free tier (only one per subscription)')
param enableFreeTier bool = false

@description('SQL database name')
param databaseName string = 'appdb'

@description('SQL container name')
param containerName string = 'appcontainer'

@description('Partition key path for the container')
param partitionKeyPath string = '/id'

@description('Throughput (RU/s) for autoscale max')
@minValue(1000)
param autoscaleMaxThroughput int = 4000

@description('Tags applied to all resources')
param tags object = {
  environment: 'production'
  workload: 'cosmosdb-sql'
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

var allLocations = concat(primaryLocation, additionalLocations)

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
    locations: allLocations
    enableAutomaticFailover: automaticFailover
    enableMultipleWriteLocations: false
    enableFreeTier: enableFreeTier
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: 'Tls12'
    networkAclBypass: 'AzureServices'
    ipRules: []
    virtualNetworkRules: []
    isVirtualNetworkFilterEnabled: false
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
    capabilities: []
    cors: []
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
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      defaultTtl: -1
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
    options: {
      autoscaleSettings: {
        maxThroughput: autoscaleMaxThroughput
      }
    }
  }
}

@description('The Cosmos DB account name')
output cosmosAccountName string = cosmosAccount.name

@description('The Cosmos DB account resource ID')
output cosmosAccountId string = cosmosAccount.id

@description('The Cosmos DB SQL endpoint')
output documentEndpoint string = cosmosAccount.properties.documentEndpoint

@description('The SQL database name')
output sqlDatabaseName string = sqlDatabase.name

@description('The SQL container name')
output sq