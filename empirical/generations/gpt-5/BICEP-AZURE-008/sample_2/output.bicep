param location string = resourceGroup().location

@minLength(3)
@maxLength(24)
param keyVaultName string

@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

param enablePurgeProtection bool = true
param enableRbacAuthorization bool = true

@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

param ipAllowlist array = []
param vnetSubnetIds array = []
@allowed([
  'AzureServices'
  'None'
])
param networkBypass string = 'AzureServices'
@allowed([
  'Allow'
  'Deny'
])
param defaultAction string = 'Deny'

param tags object = {
  environment: 'prod'
}

@description('If provided, assign Key Vault Secrets User to this principal (e.g., Web App managed identity principalId) for read-only access to secrets.')
param webAppPrincipalId string = ''

@description('Resource ID of a Log Analytics workspace to send Key Vault diagnostics to. Leave empty to skip diagnostics.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Enable a private endpoint for the Key Vault.')
param enablePrivateEndpoint bool = false

@description('Resource ID of the subnet to host the private endpoint.')
param privateEndpointSubnetResourceId string = ''

@description('Provide an existing Private DNS Zone resource ID for privatelink.vaultcore.azure.net, or leave empty to create one if createPrivateDnsZone is true.')
param privateDnsZoneId string = ''

@description('Create a Private DNS Zone (privatelink.vaultcore.azure.net) and link it to the provided VNet.')
param createPrivateDnsZone bool = false

@description('Resource ID of the Virtual Network to link with the Private DNS Zone, required if createPrivateDnsZone is true.')
param virtualNetworkResourceId string = ''

var effectivePublicNetworkAccess = enablePrivateEndpoint ? 'Disabled' : publicNetworkAccess

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enableRbacAuthorization: enableRbacAuthorization
    enablePurgeProtection: enablePurgeProtection
    softDeleteRetentionInDays: softDeleteRetentionInDays
    publicNetworkAccess: effectivePublicNetworkAccess
    networkAcls: {
      bypass: networkBypass
      defaultAction: defaultAction
      ipRules: [for ip in ipAllowlist: {
        value: string(ip)
      }]
      virtualNetworkRules: [for subnetId in vnetSubnetIds: {
        id: string(subnetId)
        ignoreMissingVnetServiceEndpoint: false
      }]
    }
  }
}

@description('Send Key Vault diagnostics to Log Analytics if a workspace is provided.')
resource kvDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceResourceId)) {
  name: 'send-to-law'
  scope: kv
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
      {
        category: 'AzurePolicyEvaluationDetails'
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

@description('Assign Key Vault Secrets User role to the provided principal for secret read access.')
resource secretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(webAppPrincipalId) && enableRbacAuthorization) {
  name: guid(kv.id, webAppPrincipalId, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6'))
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: webAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

@description('Private DNS Zone for Key Vault Private Endpoint')
resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (enablePrivateEndpoint && createPrivateDnsZone && empty(privateDnsZoneId)) {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

@description('Link the Private DNS Zone to the specified VNet.')
resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (enablePrivateEndpoint && createPrivateDnsZone && empty(privateDnsZoneId) && !empty(virtualNetworkResourceId)) {
  name: 'link-${uniqueString(virtualNetworkResourceId)}'
  parent: dnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetworkResourceId
    }
    registrationEnabled: false
  }
}

var selectedPrivateDnsZoneId = !empty(privateDnsZoneId) ? privateDnsZoneId : (createPrivateDnsZone ? dnsZone.id : '')

@description('Private Endpoint for the Key Vault')
resource pe 'Microsoft.Network/privateEndpoints@2023-09-01' = if (enablePrivateEndpoint) {
  name: 'pe-${keyVaultName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'kv-connection'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
          ]
          requestMessage: 'Access for Web App to Key Vault'
        }
      }
    ]
  }
}

@description('Associate Private DNS Zone with the Private Endpoint')
resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-05-01' = if (enablePrivateEndpoint && !empty(selectedPrivateDnsZoneId)) {
  name: 'kv-dnszonegroup'
  parent: pe
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv'
        properties: {
          privateDnsZoneId: selectedPrivateDnsZoneId
        }
      }
    ]
  }
}

output keyVaultResourceId string = kv.id
output keyVaultName string = kv.name
output keyVaultUri string = kv.properties.vaultUri