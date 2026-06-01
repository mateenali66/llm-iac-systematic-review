@description('The name of the User-Assigned Managed Identity to create.')
param managedIdentityName string

@description('The name of the existing Storage Account to grant the Managed Identity access to.')
param storageAccountName string

@description('The Azure region where the Managed Identity will be created.')
param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = existing {
  name: storageAccountName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

// 'Storage Blob Data Reader' role definition ID
resource storageBlobDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = existing {
  scope: subscription()
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentity.id, storageAccount.id, storageBlobDataReaderRole.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataReaderRole.id
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('The principal ID of the created Managed Identity.')
output managedIdentityPrincipalId string = managedIdentity.properties.principalId

@description('The resource ID of the created Managed Identity.')
output managedIdentityId string = managedIdentity.id