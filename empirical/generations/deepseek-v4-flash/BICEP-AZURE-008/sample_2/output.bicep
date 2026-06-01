param location string = resourceGroup().location
param keyVaultName string
param sku string = 'standard'
param tenantId string = subscription().tenantId
param enabledForDeployment bool = false
param enabledForDiskEncryption bool = false
param enabledForTemplateDeployment bool = false
param enableRbacAuthorization bool = true
param softDeleteRetentionInDays int = 90
param purgeProtectionEnabled bool = true
param networkAclsBypass string = 'AzureServices'
param networkAclsDefaultAction string = 'Deny'
param ipRules array = []
param vnetRules array = []
param tags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: sku
    }
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableRbacAuthorization: enableRbacAuthorization
    softDeleteRetentionInDays: softDeleteRetentionInDays
    purgeProtectionEnabled: purgeProtectionEnabled
    networkAcls: {
      bypass: networkAclsBypass
      defaultAction: networkAclsDefaultAction
      ipRules: ipRules
      virtualNetworkRules: vnetRules
    }
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultResourceId string = keyVault.id