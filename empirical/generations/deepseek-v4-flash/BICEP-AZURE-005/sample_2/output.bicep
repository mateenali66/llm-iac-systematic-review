param location string = resourceGroup().location
param sqlServerName string = 'sql-${uniqueString(resourceGroup().id)}'
param sqlDatabaseName string = 'sqldb-ecommerce-prod'
param administratorLogin string
@secure()
param administratorLoginPassword string
param firewallRuleName string = 'AllowAzureServices'
param startIpAddress string = '0.0.0.0'
param endIpAddress string = '0.0.0.0'

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'S2'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 268435456000
    readScaleOut: 'Disabled'
    zoneRedundant: false
  }
}

resource firewallRule 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  parent: sqlServer
  name: firewallRuleName
  properties: {
    startIpAddress: startIpAddress
    endIpAddress: endIpAddress
  }
}

output sqlServerFullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseId string = sqlDatabase.id