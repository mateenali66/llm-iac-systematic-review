@description('The name of the User-Assigned Managed Identity to create.')
param managedIdentityName string

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The name of the existing Storage Account to which the identity will be granted access.')
param storageAccountName string

var storageBlobDataReaderRoleDefinitionId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentity.id, storageAccount.id, storageBlobDataReaderRoleDefinitionId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleDefinitionId)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output managedIdentityResourceId string = managedIdentity.id