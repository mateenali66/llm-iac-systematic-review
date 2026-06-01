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

@description('SQL database name')
param databaseName string = 'appdb'

@description('Container name')
param containerName string = 'items'

@description('Partition key path for the container')
param partitionKeyPath string = '/id'

@description('Consistency level for the Cosmos DB account')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'

@description('Maximum throughput for autoscale (RU/s)')
@minValue(1000)
@maxValue(1000000)
param autoscaleMaxThroughput int = 4000

@description('Tags to apply to all resources')
param tags object = {
  environment: 'production'
  workload: 'cosmosdb-sql'
}

var locations = concat([
  {
    locationName: primaryRegion
    failoverPriority: 0
    isZoneRedundant: true
  }
], [for (region, i) in readRegions: {
  locationName: region
  failoverPriority: i + 1
  isZoneRedundant: true
}])

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
    enableAutomaticFailover: true
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    publicNetworkAccess: 'Enabled'
    disableKeyBasedMetadataWriteAccess: true
    disableLocalAuth: false
    enableFreeTier: false
    enableAnalyticalStorage: false
    minimalTlsVersion: 'Tls12'
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
      maxIntervalInSeconds: defaultConsistencyLevel == 'BoundedStaleness' ? 86400 : 5
      maxStalenessPrefix: defaultConsistencyLevel == 'BoundedStaleness' ? 1000000 : 100
    }
    locations: locations
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
    networkAclBypass: 'AzureServices'
    capabilities: []
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

@description('The Cosmos DB account resource ID')
output cosmosAccountId string = cosmosAccount.id

@description('The Cosmos DB account name')
output cosmosAccountName string = cosmosAccount.name

@description('The Cosmos DB document endpoint')
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint

@description('The SQL database name')
output databaseName string = sqlDatabase.name

@description('The container name')
output containerName string = sqlContainer.name

@description('The system-assigned managed identity principal ID')
output principalId string = cosmosAccount.identity.principalId