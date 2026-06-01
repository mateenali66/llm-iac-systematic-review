param location string = resourceGroup().location
param sqlServerName string = 'prodsqlserver'
param sqlDatabaseName string = 'prodsqldatabase'
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
    sku: {
      name: 'S2'
      tier: 'Standard'
    }
    zoneRedundant: false
  }
  dependsOn: [
    sqlServerResource
  ]
}

output sqlServerName string = sqlServerName
output sqlDatabaseName string = sqlDatabaseName