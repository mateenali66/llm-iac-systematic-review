@description('The name of the Key Vault to create. Must be globally unique.')
param keyVaultName string

@description('The Azure region where resources will be deployed.')
param location string = resourceGroup().location

@description('The SKU of the Key Vault. Default is Standard.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Enable soft delete on the Key Vault. Default is true.')
param enableSoftDelete bool = true

@description('Number of days to retain soft-deleted items. Default is 90.')
param softDeleteRetentionInDays int = 90

@description('Enable purge protection on the Key Vault. Default is true.')
param enablePurgeProtection bool = true

@description('Enable RBAC authorization for data plane. Default is true.')
param enableRbacAuthorization bool = true

@description('List of IP addresses or CIDR ranges allowed to access the Key Vault. Empty array means no network restrictions.')
param allowedIpRanges array = []

@description('List of virtual network subnet resource IDs allowed to access the Key Vault.')
param allowedSubnetIds array = []

@description('Enable private endpoint access only. Default is false.')
param enablePrivateEndpointOnly bool = false

@description('The tenant ID for the Key Vault. Defaults to the current tenant.')
param tenantId string = subscription().tenantId

var networkAcls = {
  defaultAction: enablePrivateEndpointOnly ? 'Deny' : 'Allow'
  bypass: 'AzureServices'
  ipRules: [for ip in allowedIpRanges: {
    value: ip
  }]
  virtualNetworkRules: [for subnetId in allowedSubnetIds: {
    id: subnetId
    ignoreMissingVnetServiceEndpoint: false
  }]
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: tenantId
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    enableRbacAuthorization: enableRbacAuthorization
    networkAcls: networkAcls
    vaultUri: ''
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultResourceId string = keyVault.id