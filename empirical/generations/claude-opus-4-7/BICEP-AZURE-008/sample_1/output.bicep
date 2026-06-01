@description('Name of the Key Vault. Must be globally unique, 3-24 alphanumeric characters and hyphens.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Azure region for the Key Vault.')
param location string = resourceGroup().location

@description('Tenant ID for the Key Vault. Defaults to the current subscription tenant.')
param tenantId string = subscription().tenantId

@description('Resource ID of the Web App that will access the Key Vault.')
param webAppResourceId string

@description('Principal ID (Object ID) of the Web App''s system-assigned managed identity.')
param webAppPrincipalId string

@description('SKU name for the Key Vault.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Enable soft delete. Recommended: true.')
param enableSoftDelete bool = true

@description('Soft delete retention in days (7-90).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection. Recommended for production.')
param enablePurgeProtection bool = true

@description('Enable RBAC authorization model (recommended over access policies).')
param enableRbacAuthorization bool = true

@description('Restrict public network access. Use Disabled with private endpoints in production.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Default network ACL action when no rules match.')
@allowed([
  'Allow'
  'Deny'
])
param networkAclsDefaultAction string = 'Deny'

@description('List of IPv4 addresses or CIDR ranges allowed to access the Key Vault.')
param allowedIpRules array = []

@description('List of virtual network subnet resource IDs allowed to access the Key Vault.')
param allowedVirtualNetworkSubnetIds array = []

@description('Log Analytics workspace resource ID for diagnostic settings. Leave empty to skip.')
param logAnalyticsWorkspaceId string = ''

@description('Resource tags.')
param tags object = {
  environment: 'production'
  workload: 'webapp-secrets'
  managedBy: 'bicep'
}

var keyVaultSecretsUserRoleId = '4633458b-17de-e7c4-12d1-9aff5f7b6e54' // Key Vault Secrets User
var keyVaultCertificateUserRoleId = 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba' // Key Vault Certificate User

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
    enabledForTemplateDeployment: false
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    enableRbacAuthorization: enableRbacAuthorization
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: networkAclsDefaultAction
      ipRules: [for ip in allowedIpRules: {
        value: ip
      }]
      virtualNetworkRules: [for subnetId in allowedVirtualNetworkSubnetIds: {
        id: subnetId
        ignoreMissingVnetServiceEndpoint: false
      }]
    }
  }
}

resource secretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableRbacAuthorization) {
  name: guid(keyVault.id, webAppPrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: webAppPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Allow Web App to read secrets (connection strings, API keys).'
  }
}

resource certificateUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableRbacAuthorization) {
  name: guid(keyVault.id, webAppPrincipalId, keyVaultCertificateUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultCertificateUserRoleId)
    principalId: webAppPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Allow Web App to read certificates.'
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${keyVaultName}-diag'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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
        retentionPolicy