param location string = resourceGroup().location
param identityName string
param storageAccountName string
param storageAccountResourceGroupName string = resourceGroup().name
param tags object = {}

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b6535-1f72-4c46-9c2b-527b4f80fa02')

resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

resource targetRg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: storageAccountResourceGroupName
}

resource sa 'Microsoft.Storage/storageAccounts@2023-04-01' existing = {
  scope: targetRg
  name: storageAccountName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sa.id, uai.properties.principalId, roleDefinitionId)
  scope: sa
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: uai.properties.principalId
    principalType: 'ServicePrincipal'
  }
}