@description('The name of the SQL logical server.')
param sqlServerName string = 'sql-ecom-${uniqueString(resourceGroup().id)}'

@description('The name of the SQL Database.')
param sqlDatabaseName string = 'sqldb-ecommerce-prod'

@description('The Azure region for all resources.')
param location string = resourceGroup().location

@description('The administrator username for the SQL server.')
param sqlAdministratorLogin string

@description('The administrator password for the SQL server.')
@secure()
param sqlAdministratorPassword string

@description('Azure AD admin login name for SQL server.')
param aadAdminLogin string

@description('Azure AD admin object ID for SQL server.')
param aadAdminObjectId string

@description('Tenant ID for Azure AD admin.')
param aadAdminTenantId string = subscription().tenantId

@description('Log Analytics workspace resource ID for diagnostic settings.')
param logAnalyticsWorkspaceId string

@description('Resource tags.')
param tags object = {
  environment: 'production'
  application: 'ecommerce'
  costCenter: 'retail'
  managedBy: 'bicep'
}

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    restrictOutboundNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: aadAdminTenantId
      azureADOnlyAuthentication: false
    }
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: tags
  sku: {
    name: 'S2'
    tier: 'Standard'
    capacity: 50
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 268435456000
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Geo'
    isLedgerOn: false
  }
}

resource transparentDataEncryption 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

resource shortTermRetention 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    retentionDays: 35
    diffBackupIntervalInHours: 12
  }
}

resource longTermRetention 'Microsoft.Sql/servers/databases/backupLongTermRetentionPolicies@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    weeklyRetention: 'P4W'
    monthlyRetention: 'P12M'
    yearlyRetention: 'P7Y'
    weekOfYear: 1
  }
}

resource securityAlertPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2023-08-01-preview' = {
  parent: sqlServer
  name: 'Default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    retentionDays: 90
    disabledAlerts: []
  }
}

resource auditingSettings 'Microsoft.Sql/servers/auditingSettings@2023-08-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: 90
    auditActionsAndGroups: [
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]
  }
}

resource vulnerabilityAssessment 'Microsoft.Sql/servers/sqlVulnerabilityAssessments@2023-08-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
  }
}

resource sqlServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlServer
  name: 'sqlServerDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
  }
}

resource sqlDatabaseDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlDatabase
  name: 'sqlDatabaseDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]