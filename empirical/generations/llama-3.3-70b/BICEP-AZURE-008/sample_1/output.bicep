param location string = resourceGroup().location
param keyVaultName string = 'myKeyVault'
param webAppName string = 'myWebApp'
param resourceGroupName string = resourceGroup().name

resource keyVaultResource 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
  }
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-11-01-preview' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicy: {
      tenantId: subscription().tenantId
      objectId: null
      permissions: {
        certificates: [
          'get'
          'list'
          'update'
        ]
        keys: [
          'get'
          'list'
          'update'
        ]
        secrets: [
          'get'
          'list'
          'set'
          'delete'
          'purge'
          'recover'
        ]
      }
    }
  }
  dependsOn: [
    keyVaultResource
  ]
}