param location string = resourceGroup().location
param cosmosAccountName string = 'cosmos-${uniqueString(resourceGroup().id)}'
param databaseName string = 'appdb'
param containerName string = 'items'

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
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
    networkAclBypass: 'None'
    disableKeyBasedMetadataWriteAccess: true
    enableFreeTier: false
  }
}

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource sqlContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: sqlDatabase
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/id'
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
      defaultTtl: 86400
    }
    options: {
      throughput: 400
    }
  }
}

output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output cosmosPrimaryKey string = listKeys(cosmosAccount.id, cosmosAccount.apiVersion).primaryMasterKey
output cosmosConnectionString string = 'AccountEndpoint=${cosmosAccount.properties.documentEndpoint};AccountKey=${listKeys(cosmosAccount.id, cosmosAccount.apiVersion).primaryMasterKey};'