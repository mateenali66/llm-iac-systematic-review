@description('The location for all resources.')
param location string = resourceGroup().location

@description('The globally unique name for the Azure SQL Server.')
param sqlServerName string = 'sqlserver-${uniqueString(resourceGroup().id)}'

@description('The name for the Azure SQL Database.')
param sqlDatabaseName string = 'sqldb-ecommerce-prod'

@description('The administrator login for the SQL Server.')
param sqlAdminLogin string

@description('The administrator password for the SQL Server.')
@secure()
param sqlAdminPassword string

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}