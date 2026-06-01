param location string = resourceGroup().location
param accountName string = 'cosmos-${uniqueString(resourceGroup().id)}'
param databaseName string = 'maindb'
param containerName string = 'items'
param partitionKeyPath string = '/partitionKey'
param throughput int = 400

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    disableKeyBasedMetadataWriteAccess: false
    enableAutomaticFailover: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    networkAclBypass: 'None'
    publicNetworkAccess: 'Enabled'
    enableFreeTier: false
    apiProperties: {
      serverVersion: '4.2'
    }
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
      }
    }
    cors: []
    ipRules: []
    virtualNetworkRules: []
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    disableLocalAuth: false
    defaultIdentity: 'FirstPartyIdentity'
  }
}

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
  parent: cosmosAccount
  name: databaseName
  location: location
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
  location: location
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          partitionKeyPath
        ]
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