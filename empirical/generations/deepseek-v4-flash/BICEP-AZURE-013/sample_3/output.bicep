param location string = resourceGroup().location
param accountName string = 'cosmos-${uniqueString(resourceGroup().id)}'
param databaseName string = 'maindb'
param containerName string = 'items'
param consistencyLevel string = 'Session'
param maxStalenessPrefix int = 100
param maxIntervalInSeconds int = 5
param primaryRegion string = location
param enableAutomaticFailover bool = false
param throughput int = 400

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: accountName
  location: primaryRegion
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: primaryRegion
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: consistencyLevel
      maxStalenessPrefix: maxStalenessPrefix
      maxIntervalInSeconds: maxIntervalInSeconds
    }
    enableAutomaticFailover: enableAutomaticFailover
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    disableKeyBasedMetadataWriteAccess: true
    networkAclBypass: 'None'
    isVirtualNetworkFilterEnabled: false
    publicNetworkAccess: 'Enabled'
    enableFreeTier: false
    enableAnalyticalStorage: false
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
    }
  }
}

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: {
      throughput: throughput
    }
  }
}

resource sqlContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  parent: sqlDatabase
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
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
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
    options: {
      throughput: throughput
    }
  }
}

output cosmosAccountEndpoint string = cosmosAccount.properties.documentEndpoint
output cosmosAccountName string = cosmosAccount.name
output primaryMasterKey string = cosmosAccount.listKeys().primaryMasterKey