param location string = resourceGroup().location
param keyVaultName string
param webAppName string
param tags object = {}

var tenantId = subscription().tenantId

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: reference(resourceId('Microsoft.Web/sites', webAppName), '2023-12-01', 'full').identity.principalId
        permissions: {
          certificates: ['get', 'list']
          secrets: ['get', 'list']
          keys: ['get', 'list']
        }
      }
    ]
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
  }
}

resource keyVaultNetworkRuleSet 'Microsoft.KeyVault/vaults/providers/Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVault.name}/Microsoft.Insights/keyVaultDiagnostics'
  dependsOn: [
    keyVault
  ]
  properties: {
    logs: [
      {
        category: 'AuditEvent'
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
        enabled: false
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}