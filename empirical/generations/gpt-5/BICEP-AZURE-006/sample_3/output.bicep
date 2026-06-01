@description('Name of the User Assigned Managed Identity to create')
param managedIdentityName string

@description('Location for the Managed Identity')
param location string = resourceGroup().location

@description('Tags to apply to the Managed Identity')
param tags object = {}

@description('Subscription ID containing the target Storage Account')
param storageAccountSubscriptionId string = subscription().subscriptionId

@description('Resource group name of the target Storage Account')
param storageAccountResourceGroupName string

@description('Name of the target Storage Account')
param storageAccountName string

var storageBlobDataReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')

resource storageRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription(storageAccountSubscriptionId)
  name: storageAccountResourceGroupName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
  scope: storageRg
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

resource storageBlobDataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.properties.principalId, storageBlobDataReaderRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataReaderRoleId
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output managedIdentityResourceId string = managedIdentity.id
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId