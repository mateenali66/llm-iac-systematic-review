param location string = resourceGroup().location
param keyVaultName string
param skuName string = 'standard'
param tenantId string = subscription().tenantId
param enabledForDeployment bool = false
param enabledForDiskEncryption bool = false
param enabledForTemplateDeployment bool = false
param enableRbacAuthorization bool = true
param softDeleteRetentionInDays int = 90
param purgeProtectionEnabled bool = true
param networkAclsDefaultAction string = 'Deny'
param networkAclsBypass string = 'AzureServices'
param allowedIpRules array = []
param allowedVirtualNetworkRules array = []
param webAppPrincipalId string = ''
param webAppName string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableRbacAuthorization: enableRbacAuthorization
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enableSoftDelete: true
    purgeProtectionEnabled: purgeProtectionEnabled
    networkAcls: {
      defaultAction: networkAclsDefaultAction
      bypass: networkAclsBypass
      ipRules: [for ip in allowedIpRules: { value: ip }]
      virtualNetworkRules: [for rule in allowedVirtualNetworkRules: { id: rule }]
    }
  }
}

resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ConnectionStrings--DefaultConnection'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
  }
}

resource keyVaultApiKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ApiKeys--Primary'
  properties: {
    value: 'placeholder'
    attributes: {
      enabled: true
    }
  }
}

resource keyVaultCertificate 'Microsoft.KeyVault/vaults/certificates@2023-07-01' = {
  parent: keyVault
  name: 'WebAppCertificate'
  properties: {
    attributes: {
      enabled: true
    }
    policy: {
      keyProperties: {
        exportable: true
        keyType: 'RSA'
        keySize: 2048
        reuseKey: false
      }
      secretProperties: {
        contentType: 'application/x-pkcs12'
      }
      x509CertificateProperties: {
        subject: 'CN=${webAppName}.azurewebsites.net'
        validityInMonths: 12
      }
      issuerParameters: {
        name: 'Self'
      }
    }
  }
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(webAppPrincipalId)) {
  name: guid(keyVault.id, webAppPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: webAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultName string = keyVault.name
output keyVaultResourceId string = keyVault.id