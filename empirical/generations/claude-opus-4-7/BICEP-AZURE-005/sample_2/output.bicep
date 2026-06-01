@description('The Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name (e.g., prod, staging).')
@allowed([
  'prod'
  'staging'
  'dev'
])
param environment string = 'prod'

@description('Workload/application name.')
param workloadName string = 'ecommerce'

@description('SQL Server administrator login name.')
@minLength(4)
param sqlAdministratorLogin string

@description('SQL Server administrator password.')
@secure()
@minLength(16)
param sqlAdministratorPassword string

@description('Azure AD admin object ID for SQL Server.')
param aadAdminObjectId string

@description('Azure AD admin login name (UPN or group name) for SQL Server.')
param aadAdminLogin string

@description('Tenant ID for Azure AD admin.')
param aadTenantId string = subscription().tenantId

@description('Log Analytics workspace resource ID for diagnostic settings.')
param logAnalyticsWorkspaceId string

@description('Tags applied to all resources.')
param tags object = {
  environment: environment
  workload: workloadName
  costCenter: 'ecommerce'
  managedBy: 'bicep'
}

var uniqueSuffix = uniqueString(resourceGroup().id, workloadName, environment)
var sqlServerName = toLower('sql-${workloadName}-${environment}-${uniqueSuffix}')
var sqlDatabaseName = toLower('sqldb-${workloadName}-${environment}')

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
      tenantId: aadTenantId
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

resource auditingSettings 'Microsoft.Sql/servers/auditingSettings@2023-08-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: 90
    auditActionsAndGroups: [
      'BATCH_COMPLETED_GROUP'
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
    ]
  }
}

resource securityAlertPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2023-08-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    retentionDays: 90
    disabledAlerts: []
  }
}

resource vulnerabilityAssessment 'Microsoft.Sql/servers/vulnerabilityAssessments@2023-08-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: true
    }
  }
  dependsOn: [
    securityAlertPolicy
  ]
}

resource sqlServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlDatabase
  name: 'diag-${sqlDatabaseName}'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLInsights'
        enabled: true
      }
      {
        category: 'AutomaticTuning'
        enabled: true
      }
      {