targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {
  environment: 'prod'
  application: 'ecommerce'
}

param sqlServerName string
param sqlDbName string
param administratorLogin string
@secure()
param administratorLoginPassword string

@description('Azure AD administrator display name for the SQL Server')
param aadAdminLogin string

@description('Object ID (GUID) of the Azure AD administrator (user or group) in the tenant')
param aadAdminObjectId string

@description('Virtual network address space for the private endpoint VNet')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('Subnet address prefix for the private endpoint subnet')
param subnetAddressPrefix string = '10.20.1.0/24'

@description('Email addresses for SQL threat detection alerts')
param securityAlertEmails array = []

@description('Retention in days for auditing and security alert storage')
param logRetentionDays int = 30

var vnetName = '${sqlServerName}-pe-vnet'
var subnetName = 'snet-pe'
var laWorkspaceName = 'law-${uniqueString(resourceGroup().id, sqlServerName)}'
var storageAccountName = toLower('st' + uniqueString(subscription().subscriptionId, resourceGroup().name, sqlServerName))
var privateDnsZoneName = 'privatelink.database.windows.net'
var diagSqlServerSettingName = 'sqlserver-diagnostics'
var diagSqlDbSettingName = 'sqldb-diagnostics'

resource laWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: laWorkspaceName
  location: location
  tags: tags
  properties: {
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
  sku: {
    name: 'PerGB2018'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    accessTier: 'Hot'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'link-${vnet.name}'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}

resource aadAdmin 'Microsoft.Sql/servers/administrators@2021-11-01-preview' = {
  name: 'ActiveDirectory'
  parent: sqlServer
  properties: {
    administratorType: 'ActiveDirectory'
    login: aadAdminLogin
    sid: aadAdminObjectId
    tenantId: tenant().tenantId
  }
}

resource aadOnly 'Microsoft.Sql/servers/aadOnlyAuthentications@2021-11-01-preview' = {
  name: 'Default'
  parent: sqlServer
  properties: {
    azureADOnlyAuthentication: true
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  name: '${sqlServer.name}/${sqlDbName}'
  location: location
  tags: tags
  sku: {
    name: 'S2'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
  }
}

resource tde 'Microsoft.Sql/servers/databases/transparentDataEncryption@2021-11-01-preview' = {
  name: '${sqlDb.name}/current'
  properties: {
    status: 'Enabled'
  }
}

resource dbShortTermRetention 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2021-11-01-preview' = {
  name: '${sqlDb.name}/default'
  properties: {
    retentionDays: 35
  }
}

resource serverAuditing 'Microsoft.Sql/servers/auditingSettings@2021-11-01-preview' = {
  name: 'Default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
    storageEndpoint: storageAccount.properties.primaryEndpoints.blob
    storageAccountAccessKey: listKeys(storageAccount.id, '2023-01-01').keys[0].value
    isAzureMonitorTargetEnabled: true
    retentionDays: logRetentionDays
  }
}

resource securityAlerts 'Microsoft.Sql/servers/securityAlertPolicies@2021-11-01-preview' = {
  name: 'Default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    emailAddresses: securityAlertEmails
    storageEndpoint: storageAccount.properties.primaryEndpoints.blob
    storageAccountAccessKey: listKeys(storageAccount.id, '2023-01-01').keys[0].value
    retentionDays: logRetentionDays
  }
}

resource sqlServerDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagSqlServerSettingName
  scope: sqlServer
  properties: {
    workspaceId: laWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource sqlDbDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagSqlDbSettingName
  scope: sqlDb
  properties: {
    workspaceId: laWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${sqlServerName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnet.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlServerName}-plsc'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-05-01' = {
  name: 'sqlserver-zone-group'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sqlserver-dnsconfig'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

output sqlServerId string = sqlServer.id
output sqlDatabaseId string = sqlDb.id
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output privateEndpointIp string = reference(privateEndpoint.id, '2023-05-01', 'Full').properties.networkInterfaces[0].ipConfigurations[0].properties.privateIPAddress