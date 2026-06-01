@description('Specifies the prefix for the Cosmos DB account name, which must be globally unique.')
@minLength(3)
@maxLength(30)
param accountNamePrefix string

@description('Specifies the primary Azure region for the Cosmos DB account.')
param primaryRegion string = resourceGroup().location

@description('Specifies the secondary Azure region for geo-replication.')
param secondaryRegion string

@description('Tags to apply to the resources.')
param tags object = {}

var cosmosDbAccountName = '${accountNamePrefix}-${uniqueString(resourceGroup().id)}'
var locations = [
  {
    locationName: primaryRegion
    failoverPriority: 0
    isZoneRedundant: false
  }
  {
    locationName: secondaryRegion
    failoverPriority: 1
    isZoneRedundant: false
  }
]

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbAccountName
  location: primaryRegion
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: locations
    databaseAccountOfferType: 'Standard'
    enableMultipleWriteLocations: false
    enableAutomaticFailover: true
    publicNetworkAccess: 'Disabled'
    disableKeyBasedMetadataWriteAccess: true
    disableLocalAuth: true
    minimalTlsVersion: 'Tls12'
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 720
        backupStorageRedundancy: 'Geo'
      }
    }
  }
}

output accountId string = cosmosDbAccount.id
output accountName string = cosmosDbAccount.name
output documentEndpoint string = cosmosDbAccount.properties.documentEndpoint