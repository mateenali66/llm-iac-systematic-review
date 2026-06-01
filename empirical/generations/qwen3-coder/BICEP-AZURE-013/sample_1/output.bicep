param location string = resourceGroup().location
param cosmosAccountName string
param databaseName string
param containerName string
param throughput int = 400

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosAccountName
  location: location
  tags: {
    Environment: 'Production'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true
      }
    ]
    enableMultipleWriteLocations: false
    enableAutomaticFailover: true
    disableKeyBasedMetadataWriteAccess: true
    publicNetworkAccess: 'Enabled'
    enableFreeTier: false
    apiProperties: {
      serverVersion: '4.0'
    }
  }
}

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  name: '${cosmosAccount.name}/${databaseName}'
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource sqlContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  name: '${cosmosAccount.name}/${databaseName}/${containerName}'
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
    options: {
      throughput: throughput
    }
  }
}