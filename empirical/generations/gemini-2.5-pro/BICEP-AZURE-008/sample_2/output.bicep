@description('Specifies the prefix for the Key Vault name. The final name will be a combination of this prefix and a unique string.')
@minLength(3)
@maxLength(14)
param keyVaultNamePrefix string

@description('Specifies the Azure location where the Key Vault should be created. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Specifies the SKU for the Key Vault.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('A set of tags to apply to the Key Vault.')
param tags object = {}

var keyVaultName = '${keyVaultNamePrefix}${uniqueString(resourceGroup().id)}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    enablePurgeProtection: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
}

@description('The name of the created Key Vault.')
output vaultName string = keyVault.name

@description('The URI of the created Key Vault.')
output vaultUri string = keyVault.properties.vaultUri

@description('The resource ID of the created Key Vault.')
output resourceId string = keyVault.id