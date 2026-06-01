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
    softDeleteRetentionInDays: 7
  }
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-11-01-preview' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicy: {
      tenantId: subscription().tenantId
      objectId: null
      permissions: {
        keys: [
          'get'
          'list'
          'update'
          'create'
          'import'
          'delete'
          'recover'
          'backup'
          'restore'
        ]
        secrets: [
          'get'
          'list'
          'set'
          'delete'
          'recover'
          'backup'
          'restore'
        ]
        certificates: [
          'get'
          'list'
          'update'
          'create'
          'import'
          'delete'
          'recover'
          'backup'
          'restore'
        ]
      }
    }
  }
  dependsOn: [
    keyVaultResource
  ]
}

output keyVaultId string = keyVaultResource.id
output keyVaultNameOutput string = keyVaultName