param location string = resourceGroup().location
param sqlServerName string
param sqlDatabaseName string
param sqlAdminUsername string
@secure()
param sqlAdminPassword string

@description('Azure AD administrator display name (login) for the SQL server.')
param aadAdminLogin string
@description('Azure AD administrator object (principal) ID for the SQL server.')
param aadAdminObjectId string
@description('Azure AD tenant ID for the administrator.')
param aadAdminTenantId string = tenant().tenantId

@allowed([
  'Enabled'
  'Disabled'
])
@description('Controls public network access to the SQL server. For production, Disabled is recommended.')
param publicNetworkAccess string = 'Disabled'

@allowed([
  '1.2'
])
@description('Minimal TLS version for the SQL server.')
param minimalTlsVersion string = '1.2'

@description('Resource ID of an existing Log Analytics workspace for SQL Auditing. Leave empty to skip configuring auditing to Log Analytics.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Enable a Private Endpoint for the SQL server. Strongly recommended for production.')
param enablePrivateEndpoint bool = true

@description('Resource ID of the subnet to host the Private Endpoint (required if enablePrivateEndpoint=true).')
param subnetResourceId string = ''

@description('Create a new Private DNS zone (privatelink.database.windows.net) in this resource group. If false, provide existingPrivateDnsZoneId.')
param createPrivateDnsZone bool = true

@description('Resource ID of an existing Private DNS zone privatelink.database.windows.net. Used when createPrivateDnsZone=false.')
param existingPrivateDnsZoneId string = ''

@minValue(1)
@maxValue(1024)
@description('Maximum database size in GB.')
param maxSizeGB int = 250

@minValue(7)
@maxValue(35)
@description('Short-term backup retention in days.')
param shortTermRetentionDays int = 14

@description('Database collation.')
param collation string = 'SQL_Latin1_General_CP1_CI_AS'

@description('Optional firewall rules (applies only when public network access is Enabled). Each entry must include: name, startIpAddress, endIpAddress.')
param firewallRules array = []

@description('Common resource tags.')
param tags object = {
  environment: 'prod'
}

var privateDnsZoneName = 'privatelink.database.windows.net'
var subnetPathSuffix = '/subnets/'
var vnetResourceId = substring(subnetResourceId, 0, indexOf(subnetResourceId, subnetPathSuffix))

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: minimalTlsVersion
    publicNetworkAccess: publicNetworkAccess
  }
}

resource sqlServerAadAdmin 'Microsoft.Sql/servers/administrators@2022-02-01-preview' = {
  name: 'ActiveDirectory'
  parent: sqlServer
  properties: {
    administratorType: 'ActiveDirectory'
    login: aadAdminLogin
    sid: aadAdminObjectId
    tenantId: aadAdminTenantId
  }
}

resource sqlServerAadOnly 'Microsoft.Sql/servers/azureADOnlyAuthentications@2022-02-01-preview' = {
  name: 'Default'
  parent: sqlServer
  properties: {
    azureADOnlyAuthentication: true
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  name: '${sqlServer.name}/${sqlDatabaseName}'
  location: location
  tags: union(tags, {
    workload: 'ecommerce'
  })
  sku: {
    name: 'S2'
    tier: 'Standard'
    capacity: 50
  }
  properties: {
    collation: collation
    maxSizeBytes: maxSizeGB * 1024 * 1024 * 1024
    zoneRedundant: false
    requestedBackupStorageRedundancy: 'Geo'
  }
}

resource sqlDatabaseTde 'Microsoft.Sql/servers/databases/transparentDataEncryption@2022-02-01-preview' = {
  name: '${sqlDatabase.name}/current'
  properties: {
    state: 'Enabled'
  }
}

resource shortTermRetention 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2022-02-01-preview' = {
  name: '${sqlDatabase.name}/default'
  properties: {
    retentionDays: shortTermRetentionDays
  }
}

resource serverAuditing 'Microsoft.Sql/servers/auditingSettings@2021-02-01-preview' = if (!empty(logAnalyticsWorkspaceResourceId)) {
  name: 'default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    workspaceResourceId: logAnalyticsWorkspaceResourceId
    auditActionsAndGroups: [
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'BATCH_STARTED_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]
    retentionDays: 0
  }
}

resource serverFirewallRules 'Microsoft.Sql/servers/firewallRules@2022-02-01-preview' = if (publicNetworkAccess == 'Enabled') [for rule in firewallRules: {
  name: rule.name
  parent: sqlServer
  properties: {
    startIpAddress: rule.startIpAddress
    endIpAddress: rule.endIpAddress
  }
}]

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = if (enablePrivateEndpoint && createPrivateDnsZone) {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = if (enablePrivateEndpoint && createPrivateDnsZone) {
  name: '${privateDnsZone.name}/${uniqueString(vnetResourceId)}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetResourceId
    }
    registrationEnabled: false
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = if (enablePrivateEndpoint) {
  name: '${sqlServer.name}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'sqlServerConnection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
          requestMessage: 'Private Endpoint connection for Azure SQL Server'
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = if (enablePrivateEndpoint) {
  name: '${privateEndpoint.name}/sqlserver-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sqlserver-dns-zone-config'
        properties: {
          privateDnsZoneId: createPrivateDnsZone ? privateDnsZone.id : existingPrivateDnsZoneId
        }
      }
    ]
  }
}

output sqlServerResourceId string = sqlServer.id
output sqlDatabaseResourceId string = sqlDatabase.id