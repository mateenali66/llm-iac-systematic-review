param location string = resourceGroup().location
param cosmosAccountName string
param primaryRegion string
param secondaryRegion string

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
        locationName: primaryRegion
        failoverPriority: 0
        isZoneRedundant: true
      }
      {
        locationName: secondaryRegion
        failoverPriority: 1
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
    apiProperties: {
      serverVersion: '4.0'
    }
  }
}

output cosmosAccountEndpoint string = cosmosAccount.properties.documentEndpoint
output cosmosAccountKey string = listKeys(cosmosAccount.id, cosmosAccount.apiVersion).primaryMasterKey