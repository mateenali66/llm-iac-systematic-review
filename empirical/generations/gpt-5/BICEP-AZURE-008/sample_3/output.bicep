param name string
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'
param location string = resourceGroup().location
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90
param enablePurgeProtection bool = true
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'
@description('IP CIDR ranges allowed when publicNetworkAccess is Enabled, e.g., ["1.2.3.4/32"]. Leave empty to deny all.')
param allowedIpRules array = []
@description('Tags to apply to all resources.')
param tags object = {}

@description('Set to true to create a Private Endpoint for the Key Vault.')
param deployPrivateEndpoint bool = true
@description('Resource ID of the subnet to host the Private Endpoint. Required when deployPrivateEndpoint is true.')
param subnetResourceId string = ''

@description('Provide an existing Private DNS zone resource ID for privatelink.vaultcore.azure.net, or leave empty to create one if createPrivateDnsZone is true.')
param privateDnsZoneResourceId string = ''
@description('Create a new Private DNS zone (privatelink.vaultcore.azure.net) if no existing zone is supplied.')
param createPrivateDnsZone bool = true
@description('Name of the Private DNS zone to create if createPrivateDnsZone is true.')
param dnsZoneName string = 'privatelink.vaultcore.azure.net'
@description('Virtual Network resource ID to link to the Private DNS zone (optional but recommended).')
param vnetIdForDnsLink string = ''

@description('Principal (object) IDs to assign the Key Vault Secrets User role for secret read access.')
param principalIdsSecretsUser array = []
@description('Principal (object) IDs to assign the Key Vault Certificates Officer role for certificate management.')
param principalIdsCertOfficer array = []
@description('Principal (object) IDs to assign the Key Vault Reader role for vault metadata read.')
param principalIdsReader array = []

@description('Optional Log Analytics Workspace resource ID for diagnostic logs and metrics. Leave empty to skip.')
param logAnalyticsWorkspaceResourceId string = ''

var secretsUserRoleDefId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
var certOfficerRoleDefId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a4417e6f-fecd-4de8-b567-7b0420556985')
var readerRoleDefId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '21090545-7ca7-4776-b22c-e363652d74d2')

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enableRbacAuthorization: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      ipRules: [for ip in allowedIpRules: {
        value: string(ip)
      }]
      virtualNetworkRules: []
    }
  }
}

resource secretsUserAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for pid in principalIdsSecretsUser: {
  name: guid(keyVault.id, pid, secretsUserRoleDefId)
  scope: keyVault
  properties: {
    roleDefinitionId: secretsUserRoleDefId
    principalId: pid
  }
}]

resource certOfficerAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for pid in principalIdsCertOfficer: {
  name: guid(keyVault.id, pid, certOfficerRoleDefId)
  scope: keyVault
  properties: {
    roleDefinitionId: certOfficerRoleDefId
    principalId: pid
  }
}]

resource readerAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for pid in principalIdsReader: {
  name: guid(keyVault.id, pid, readerRoleDefId)
  scope: keyVault
  properties: {
    roleDefinitionId: readerRoleDefId
    principalId: pid
  }
}]

var privateDnsZoneIdToUse = privateDnsZoneResourceId != '' ? privateDnsZoneResourceId : (createPrivateDnsZone ? resourceId('Microsoft.Network/privateDnsZones', dnsZoneName) : '')

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = if(createPrivateDnsZone && privateDnsZoneResourceId == '') {
  name: dnsZoneName
  location: 'global'
  tags: tags
}

var vnetNameForLink = vnetIdForDnsLink != '' ? last(split(vnetIdForDnsLink, '/')) : ''

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = if(createPrivateDnsZone && vnetIdForDnsLink != '') {
  name: '${dnsZoneName}/${vnetNameForLink}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetIdForDnsLink
    }
  }
  dependsOn: [
    privateDnsZone
  ]
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = if(deployPrivateEndpoint) {
  name: '${name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'kv-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-03-01' = if(deployPrivateEndpoint && privateDnsZoneIdToUse != '') {
  name: 'kv-dnszonegroup'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv-dns-config'
        properties: {
          privateDnsZoneId: privateDnsZoneIdToUse
        }
      }
    ]
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(logAnalyticsWorkspaceResourceId != '') {
  name: 'kv-diag'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output keyVaultName string = keyVault.name
output keyVaultResourceId string = keyVault.id
output keyVaultVaultUri string = keyVault.properties.vaultUri
output privateEndpointId string = deployPrivateEndpoint ? privateEndpoint.id : ''