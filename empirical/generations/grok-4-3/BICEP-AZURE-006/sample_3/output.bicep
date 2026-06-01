param managedIdentityName string
param location string = resourceGroup().location
param storageAccountId string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

var roleDefinitionId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentity.id, roleDefinitionId, storageAccountId)
  scope: resourceId('Microsoft.Storage/storageAccounts', last(split(storageAccountId, '/')))
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}