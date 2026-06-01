param roleName string = 'Custom VM Reader'
param roleDescription string = 'Read-only access to virtual machines'
param principalId string
param assignableScope string = subscription().id

resource customRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(roleName, assignableScope)
  properties: {
    roleName: roleName
    description: roleDescription
    assignableScopes: [
      assignableScope
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/vmSizes/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(principalId, customRole.id)
  properties: {
    roleDefinitionId: customRole.id
    principalId: principalId
    principalType: 'Group'
    scope: assignableScope
  }
}