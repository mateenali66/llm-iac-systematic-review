@description('The name of the User-Assigned Managed Identity to create.')
param managedIdentityName string

@description('The name of the existing Storage Account to grant access to.')
param storageAccountName string

@description('The Azure region where the Managed Identity will be created. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The principal type for the role assignment. User-assigned identities use ServicePrincipal.')
param principalType string = 'ServicePrincipal'

var storageBlobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentity.id, storageAccount.id, storageBlobDataReaderRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
    principalId: managedIdentity.properties.principalId
    principalType: principalType
  }
}

@description('The resource ID of the created User-Assigned Managed Identity.')
output managedIdentityResourceId string = managedIdentity.id

@description('The principal ID (service principal object ID) of the created User-Assigned Managed Identity.')
output managedIdentityPrincipalId string = managedIdentity.properties.principalId