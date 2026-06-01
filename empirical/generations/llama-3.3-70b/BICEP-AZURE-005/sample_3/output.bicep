param location string = resourceGroup().location
param sqlServerName string = 'prodsqlserver'
param sqlDatabaseName string = 'prodecommerce'
param administratorLogin string = 'sqladmin'
param administratorLoginPassword string = 'P@ssw0rd1234'

resource sqlServerResource 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  }
}

resource sqlDatabaseResource 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: '${sqlServerName}/${sqlDatabaseName}'
  location: location
  properties: {
    edition: 'Standard'
    requestedServiceObjectiveName: 'S2'
  }
  dependsOn: [
    sqlServerResource
  ]
}

resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  name: '${sqlServerName}/AllowAzureServices'
  location: location
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  dependsOn: [
    sqlServerResource
  ]
}

output sqlServerName string = sqlServerName
output sqlDatabaseName string = sqlDatabaseName
output sqlServerFullyQualifiedDomainName string = sqlServerResource.properties.fullyQualifiedDomainName