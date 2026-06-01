param location string = resourceGroup().location
@minLength(3)
@description('Name of the User Assigned Managed Identity to create.')
param identityName string
@description('Name of the target Storage Account.')
param storageAccountName string
@description('Resource group name of the target Storage Account.')
param storageAccountResourceGroup string
@description('Subscription ID of the target Storage Account. Defaults to the current subscription.')
param storageAccountSubscriptionId string = subscription().subscriptionId
@description('Optional tags to apply to created resources.')
param tags object = {}

resource saRg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: storageAccountResourceGroup
  scope: subscription(storageAccountSubscriptionId)
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
  scope: saRg
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

var storageBlobDataReaderRoleId = subscriptionResourceId(storageAccountSubscriptionId, 'Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')

resource blobReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, storageBlobDataReaderRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataReaderRoleId
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output managedIdentityId string = managedIdentity.id
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output roleAssignmentId string = blobReaderAssignment.id