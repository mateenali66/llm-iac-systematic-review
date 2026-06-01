param managedIdentityName string
param location string = resourceGroup().location
param storageAccountResourceId string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentity.id, storageAccountResourceId, '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
  scope: storageAccountResourceId
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}