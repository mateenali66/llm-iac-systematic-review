@description('Azure region for resources.')
param location string = resourceGroup().location

@description('Name of the user-assigned managed identity.')
@minLength(3)
@maxLength(128)
param managedIdentityName string

@description('Name of the existing Storage Account to grant access to.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Resource group name of the existing Storage Account. Defaults to current resource group.')
param storageAccountResourceGroupName string = resourceGroup().name

@description('Tags applied to created resources.')
param tags object = {}

// Built-in role definition ID for 'Storage Blob Data Reader'
var storageBlobDataReaderRoleDefinitionId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
  scope: resourceGroup(storageAccountResourceGroupName)
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, storageBlobDataReaderRoleDefinitionId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleDefinitionId)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    description: 'Grants the user-assigned managed identity read access to blob data on the target storage account.'
  }
}

@description('Resource ID of the created managed identity.')
output managedIdentityId string = managedIdentity.id

@description('Client ID of the created managed identity.')
output managedIdentityClientId string = managedIdentity.properties.clientId

@description('Principal (object) ID of the created managed identity.')
output managedIdentityPrincipalId string = managedIdentity.properties.principalId

@description('Name of the created role assignment (GUID).')
output roleAssignmentName string = roleAssignment.name