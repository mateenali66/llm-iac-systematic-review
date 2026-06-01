param location string = resourceGroup().location
param accountName string = 'cosmosdbaccount'

resource cosmosDbAccountResource 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
  name: accountName
  location: location
  properties: {
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    enableCassandra: false
    enableTable: false
    enableGremlin: false
    enableSql: true
  }
  kind: 'GlobalDocumentDB'
  dependsOn: []
}

output accountName string = cosmosDbAccountResource.name
output primaryKey string = cosmosDbAccountResource.properties.primaryKey
output connectionString string = 'Account=${accountName};AccountKey=${primaryKey};TableEndpoint=${cosmosDbAccountResource.properties.documentEndpoint}'