@description('The base name for the Key Vault. The name will be made globally unique.')
param keyVaultBaseName string

@description('The Azure region where the resources should be deployed.')
param location string = resourceGroup().location

@description('The SKU of the Key Vault.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Tags to apply to the Key Vault.')
param tags object = {}

var keyVaultName = '${keyVaultBaseName}-${uniqueString(resourceGroup().id)}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
  }
}

output name string = keyVault.name
output uri string = keyVault.properties.vaultUri
output resourceId string = keyVault.id