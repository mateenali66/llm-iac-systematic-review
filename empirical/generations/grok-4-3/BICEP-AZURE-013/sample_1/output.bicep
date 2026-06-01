param location string = resourceGroup().location
param accountName string
param secondaryLocation string = 'eastus'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true
      }
      {
        locationName: secondaryLocation
        failoverPriority: 1
        isZoneRedundant: true
      }
    ]
    enableMultipleWriteLocations: false
    enableAutomaticFailover: true
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxStalenessPrefix: 100000
      maxIntervalInSeconds: 300
    }
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 720
        backupStorageRedundancy: 'Geo'
      }
    }
    networkAclBypass: 'None'
    publicNetworkAccess: 'Enabled'
  }
}