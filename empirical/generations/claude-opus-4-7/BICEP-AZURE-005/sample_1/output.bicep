@description('The Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name (e.g., prod, staging).')
@allowed([
  'prod'
  'staging'
  'dev'
])
param environment string = 'prod'

@description('Application name used in resource naming.')
param applicationName string = 'ecommerce'

@description('SQL Server administrator login name.')
param sqlAdminLogin string

@description('SQL Server administrator password.')
@secure()
@minLength(16)
param sqlAdminPassword string

@description('Azure AD admin object ID for SQL Server.')
param aadAdminObjectId string

@description('Azure AD admin login name (UPN or group name).')
param aadAdminLogin string

@description('Tenant ID for Azure AD authentication.')
param tenantId string = subscription().tenantId

@description('Object ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Tags to apply to all resources.')
param tags object = {
  environment: environment
  application: applicationName
  workload: 'ecommerce-database'
  costCenter: 'ecommerce'
  managedBy: 'bicep'
}

var uniqueSuffix = uniqueString(resourceGroup().id, applicationName, environment)
var sqlServerName = toLower('sql-${applicationName}-${environment}-${uniqueSuffix}')
var sqlDatabaseName = '${applicationName}-db-${environment}'

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    restrictOutboundNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: tenantId
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

resource sqlDatabaseShortTermBackup 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    retentionDays: 35
    diffBackupIntervalInHours: 12
  }
}

resource sqlDatabaseLongTermBackup 'Microsoft.Sql/servers/databases/backupLongTermRetentionPolicies@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    weeklyRetention: 'P4W'
    monthlyRetention: 'P12M'
    yearlyRetention: 'P7Y'
    weekOfYear: 1
  }
}

resource transparentDataEncryption 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

resource sqlServerAuditingSettings 'Microsoft.Sql/servers/auditingSettings@2023-08-01-preview' = {
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

resource sqlServerSecurityAlertPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2023-08-01-preview' = {
  parent: sqlServer
  name: 'Default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    retentionDays: 90
  }
}

resource sqlServerVulnerabilityAssessment 'Microsoft.Sql/servers/vulnerabilityAssessments@2023-08-01-preview' = {
  parent: sqlServer
  name: 'Default'
  properties: {
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: true
    }
  }
  dependsOn: [
    sqlServerSecurityAlertPolicy
  ]
}

resource sqlServerDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlServer
  name: 'sqlServerDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'DevOpsOperationsAudit'
        enabled: true
      }
      {
        category: 'S