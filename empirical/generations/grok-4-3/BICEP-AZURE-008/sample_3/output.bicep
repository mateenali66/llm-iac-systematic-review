targetScope = 'resourceGroup'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the Key Vault. Must be globally unique.')
param keyVaultName string

@description('SKU of the Key Vault.')
@allowed(['standard', 'premium'])
param keyVaultSku string = 'standard'

@description('Object ID of the security principal that will be granted full access to the Key Vault.')
param adminObjectId string

@description('Resource ID of the Web App managed identity that will consume secrets.')
param webAppIdentityObjectId string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: keyVaultSku
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource keyVaultAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, adminObjectId, 'Key Vault Administrator')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b860d8650cd')
    principalId: adminObjectId
    principalType: 'User'
  }
}

resource webAppSecretsRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(webAppIdentityObjectId)) {
  scope: keyVault
  name: guid(keyVault.id, webAppIdentityObjectId, 'Key Vault Secrets User')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: webAppIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

resource webAppCertsRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(webAppIdentityObjectId)) {
  scope: keyVault
  name: guid(keyVault.id, webAppIdentityObjectId, 'Key Vault Certificate User')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db79e401-6d5f-44e9-8400-2f6e2e6c2e0e')
    principalId: webAppIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri