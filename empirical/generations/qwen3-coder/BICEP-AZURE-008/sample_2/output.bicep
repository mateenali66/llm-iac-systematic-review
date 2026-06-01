param location string = resourceGroup().location
param keyVaultName string
param webAppName string
param allowedAppServicePrincipalId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: allowedAppServicePrincipalId
        tenantId: subscription().tenantId
        permissions: {
          certificates: [
            'get'
            'list'
            'create'
            'import'
          ]
          secrets: [
            'get'
            'list'
            'set'
          ]
          keys: [
            'get'
            'list'
            'create'
          ]
        }
      }
    ]
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: false
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource certificateSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'webapp-certificate'
  properties: {
    value: ''
    contentType: 'application/x-pkcs12'
  }
}

resource connectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'database-connection-string'
  properties: {
    value: ''
    contentType: 'text/plain'
  }
}

resource apiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'api-key'
  properties: {
    value: ''
    contentType: 'text/plain'
  }
}

output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri