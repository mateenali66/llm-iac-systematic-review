param location string = resourceGroup().location
param tags object = {}
param kvName string
param webAppName string
param appServicePlanName string
param appServicePlanSkuName string = 'P1v3'
param appServicePlanSkuTier string = 'PremiumV3'
param tenantId string = deployment().properties.templateHash != '' ? tenant().tenantId : tenant().tenantId
param kvSkuName string = 'standard'
param enablePurgeProtection bool = true
param softDeleteRetentionInDays int = 90

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSkuName
    tier: appServicePlanSkuTier
    size: appServicePlanSkuName
    capacity: 1
  }
  properties: {
    reserved: false
    zoneRedundant: false
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: appServicePlan.id
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: kvSkuName
    }
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    enablePurgeProtection: enablePurgeProtection
    softDeleteRetentionInDays: softDeleteRetentionInDays
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource secretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webApp.identity.principalId, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    webApp
    keyVault
  ]
}

resource certificatesUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webApp.identity.principalId, 'a4417e6f-fecd-4de8-b567-7b0420556985')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a4417e6f-fecd-4de8-b567-7b0420556985') // Key Vault Certificates User
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    webApp
    keyVault
  ]
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output webAppPrincipalId string = webApp.identity.principalId
output webAppNameOut string = webApp.name