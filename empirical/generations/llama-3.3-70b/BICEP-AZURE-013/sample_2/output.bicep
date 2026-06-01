param location string = resourceGroup().location
param accountName string = 'cosmosdbaccount'

resource cosmosDbAccountResource 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxStalenessPrefix: 100
      maxIntervalInSeconds: 5
    }
    enableCassandra: false
    enableTable: false
    enableGremlin: false
    enableAggregationPipeline: false
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    enableFreeTier: false
    apiProperties: {
      serverVersion: '4.0'
    }
  }
}

output accountName string = cosmosDbAccountResource.name
output primaryKey string = cosmosDbAccountResource.properties.primaryKey
output connectionString string = 'Account=${cosmosDbAccountResource.name};AccountKey=${cosmosDbAccountResource.properties.primaryKey};TableEndpoint=${cosmosDbAccountResource.properties.tableEndpoint}'