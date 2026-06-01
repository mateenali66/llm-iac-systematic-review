@description('Name of the Cosmos DB account')
param accountName string

@description('Primary Azure region for the account')
param primaryLocation string = 'eastus'

@description('Secondary Azure region for read replication')
param secondaryLocation string = 'westus'

@description('Default consistency level')
@allowed([
  'Eventual'
  'Session'
  'BoundedStaleness'
  'Strong'
  'ConsistentPrefix'
])
param defaultConsistencyLevel string = 'Session'

@description('Enable automatic failover')
param enableAutomaticFailover bool = true

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: primaryLocation
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: primaryLocation
        failoverPriority: 0
        isZoneRedundant: true
      }
      {
        locationName: secondaryLocation
        failoverPriority: 1
        isZoneRedundant: true
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
      maxStalenessPrefix: 100000
      maxIntervalInSeconds: 300
    }
    enableMultipleWriteLocations: false
    enableAutomaticFailover: enableAutomaticFailover
    publicNetworkAccess: 'Enabled'
    ipRules: []
    disableKeyBasedMetadataWriteAccess: true
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}