targetScope = 'subscription'

@description('Name of the custom RBAC role')
param roleName string = 'Custom VM Reader'

@description('Description of the custom RBAC role')
param roleDescription string = 'Read-only access to virtual machines'

@description('Object ID of the Azure AD security group')
param principalId string

@description('Scope for the role definition and assignment (e.g. /subscriptions/{id})')
param assignableScope string = subscription().id

var roleDefinitionName = guid(roleName, assignableScope)

resource customRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionName
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    assignableScopes: [
      assignableScope
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
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
  name: guid(principalId, customRoleDefinition.id, assignableScope)
  properties: {
    roleDefinitionId: customRoleDefinition.id
    principalId: principalId
    principalType: 'Group'
    scope: assignableScope
  }
}