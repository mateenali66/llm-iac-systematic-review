targetScope = 'resourceGroup'

@description('The name of the Cosmos DB account.')
param accountName string

@description('The primary location for the Cosmos DB account.')
param primaryLocation string = resourceGroup().location

@description('The secondary location for global distribution.')
param secondaryLocation string

@description('The default consistency level for the account.')
param defaultConsistencyLevel string = 'Session'

@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param consistencyLevel string = defaultConsistencyLevel

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
      defaultConsistencyLevel: consistencyLevel
      maxStalenessPrefix: 100000
      maxIntervalInSeconds: 300
    }
    enableMultipleWriteLocations: false
    enableAutomaticFailover: true
    publicNetworkAccess: 'Enabled'
    ipRules: []
    isVirtualNetworkFilterEnabled: false
    capabilities: []
    disableKeyBasedMetadataWriteAccess: false
    enableFreeTier: false
    enableAnalyticalStorage: false
    networkAclBypass: 'None'
    networkAclBypassResourceIds: []
  }
}