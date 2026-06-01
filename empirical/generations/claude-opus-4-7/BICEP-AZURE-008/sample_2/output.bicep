@description('Name of the Key Vault. Must be globally unique, 3-24 chars, alphanumeric and hyphens.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Azure region for the Key Vault.')
param location string = resourceGroup().location

@description('Name of the existing Web App that will access the Key Vault.')
param webAppName string

@description('Tenant ID for the Key Vault. Defaults to the subscription tenant.')
param tenantId string = subscription().tenantId

@description('SKU for the Key Vault.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Enable soft delete. Strongly recommended for production.')
param enableSoftDelete bool = true

@description('Soft delete retention in days (7-90).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection. Cannot be disabled once enabled.')
param enablePurgeProtection bool = true

@description('Enable RBAC authorization (recommended over access policies).')
param enableRbacAuthorization bool = true

@description('Public network access setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('IP rules allowed to access the Key Vault when public access is enabled.')
param allowedIpRules array = []

@description('Virtual network subnet resource IDs allowed to access the Key Vault.')
param allowedSubnetIds array = []

@description('Log Analytics workspace resource ID for diagnostic settings. Leave empty to skip.')
param logAnalyticsWorkspaceId string = ''

@description('Resource tags.')
param tags object = {
  environment: 'production'
  workload: 'webapp-secrets'
}

resource webApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: webAppName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    enableRbacAuthorization: enableRbacAuthorization
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [for ip in allowedIpRules: {
        value: ip
      }]
      virtualNetworkRules: [for subnetId in allowedSubnetIds: {
        id: subnetId
        ignoreMissingVnetServiceEndpoint: false
      }]
    }
  }
}

var keyVaultSecretsUserRoleId = '4633458b-17de-41a5-8b08-93745df910b'

resource secretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableRbacAuthorization) {
  name: guid(keyVault.id, webApp.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: webApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 365
        }
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 365
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 365
        }
      }
    ]
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri