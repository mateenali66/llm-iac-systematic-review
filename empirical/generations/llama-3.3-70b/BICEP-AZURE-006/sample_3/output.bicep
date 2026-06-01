param storageAccountName string = 'yourstorageaccountname'
param location string = resourceGroup().location
param managedIdentityName string = 'yourmanagedidentityname'

resource managedIdentity 'Microsoft.ManagedIdentity/managedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
  properties: {
    tenantId: subscription().tenantId
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(managedIdentityName, storageAccountName, 'Storage Blob Data Reader')
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df1e0d0f'
    scope: storageAccount.id
  }
  dependsOn: [
    managedIdentity
    storageAccount
  ]
}