param location string = resourceGroup().location
param sqlServerName string = 'sql-${uniqueString(resourceGroup().id)}'
param sqlDatabaseName string = 'sqldb-ecommerce-prod'
param administratorLogin string
@secure()
param administratorLoginPassword string
param collation string = 'SQL_Latin1_General_CP1_CI_AS'
param maxSizeBytes int = 268435456000
param sampleName string = ''
param zoneRedundant bool = false
param readScaleOut string = 'Disabled'
param highAvailabilityReplicaCount int = 0
param tags object = {
  environment: 'production'
  application: 'e-commerce'
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: tags
  sku: {
    name: 'S2'
    tier: 'Standard'
  }
  properties: {
    collation: collation
    maxSizeBytes: maxSizeBytes
    sampleName: sampleName
    zoneRedundant: zoneRedundant
    readScaleOut: readScaleOut
    highAvailabilityReplicaCount: highAvailabilityReplicaCount
    requestedBackupStorageRedundancy: 'Geo'
    maintenanceConfigurationId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Maintenance/publicMaintenanceConfigurations/SQL_Default'
  }
}

resource firewallRuleAllowAzureServices 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseId string = sqlDatabase.id