param location string = resourceGroup().location

@minLength(1)
@maxLength(63)
param sqlServerName string

@minLength(1)
param administratorLogin string

@secure()
param administratorLoginPassword securestring

@description('Azure AD admin display name for the SQL server.')
param aadAdminLogin string

@description('Object ID (GUID) of the Azure AD admin (user or group).')
param aadAdminObjectId string

@description('Tenant ID for the Azure AD admin.')
param aadAdminTenantId string = tenant().tenantId

@description('Azure SQL database name.')
@minLength(1)
param databaseName string

@description('Resource ID of the Log Analytics Workspace to send diagnostics and audit logs.')
param logAnalyticsWorkspaceResourceId string

@description('Resource ID of the Virtual Network where the Private DNS zone will be linked.')
param vnetResourceId string

@description('Resource ID of the subnet where the Private Endpoint will be created.')
param subnetResourceId string

@description('Email addresses to notify for SQL threat detection alerts.')
param emailSecurityContacts array = []

@description('Short-term backup retention in days (7-35).')
@minValue(7)
@maxValue(35)
param shortTermRetentionDays int = 14

@description('Resource tags to apply to all resources.')
param tags object = {}

var dnsZoneName = 'privatelink.database.windows.net'

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: '12.0'
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
    administrators: {
      administratorType: 'ActiveDirectory'
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: aadAdminTenantId
      azureADOnlyAuthentication: true
    }
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  name: '${sqlServer.name}/${databaseName}'
  location: location
  tags: tags
  sku: {
    name: 'S2'
    tier: 'Standard'
  }
  properties: {}
}

resource shortTermBackupPolicy 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2021-11-01' = {
  name: '${sqlDatabase.name}/default'
  properties: {
    retentionDays: shortTermRetentionDays
  }
}

resource serverAuditing 'Microsoft.Sql/servers/auditingSettings@2021-11-01' = {
  name: '${sqlServer.name}/default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    auditActionsAndGroups: [
      'BATCH_COMPLETED_GROUP'
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
    ]
    retentionDays: 0
  }
}

resource serverSecurityAlerts 'Microsoft.Sql/servers/securityAlertPolicies@2021-11-01' = {
  name: '${sqlServer.name}/Default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    emailAddresses: length(emailSecurityContacts) > 0 ? join(emailSecurityContacts, ';') : ''
    retentionDays: 30
    disabledAlerts: ''
  }
}

resource diagSqlServer 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'sqlserver-diag'
  scope: sqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource diagSqlDatabase 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'sqldb-diag'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
  tags: tags
}

resource privateDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${privateDnsZone.name}/${uniqueString(vnetResourceId)}-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetResourceId
    }
    registrationEnabled: false
  }
}

resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: '${sqlServer.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlServer.name}-pe-conn'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
          requestMessage: 'Private Endpoint for Azure SQL logical server'
        }
      }
    ]
  }
}

resource sqlPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-08-01' = {
  name: '${sqlPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql-dns'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}