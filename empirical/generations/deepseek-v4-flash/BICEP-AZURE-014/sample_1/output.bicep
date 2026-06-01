param location string = resourceGroup().location
param securityGroupObjectId string
param roleName string = 'Virtual Machine Reader Custom'
param roleDescription string = 'Custom role granting read-only access to virtual machines'

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(roleName, subscription().id)
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/vmSizes/read'
          'Microsoft.Compute/locations/vmSizes/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Storage/storageAccounts/read'
          'Microsoft.ResourceHealth/availabilityStatuses/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(securityGroupObjectId, roleDefinition.id, subscription().id)
  properties: {
    roleDefinitionId: roleDefinition.id
    principalId: securityGroupObjectId
    principalType: 'Group'
  }
}