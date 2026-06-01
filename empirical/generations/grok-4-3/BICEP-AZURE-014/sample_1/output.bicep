targetScope = 'subscription'

@description('Name of the custom role')
param roleName string = 'Custom VM Reader Role'

@description('Description of the custom role')
param roleDescription string = 'Read-only access to virtual machines'

@description('Object ID of the security group to assign the role to')
param securityGroupObjectId string

@description('Scope for role assignment (defaults to current subscription)')
param assignmentScope string = subscription().id

resource customRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(roleName, subscription().id)
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/vmSizes/read'
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
  name: guid(customRoleDefinition.id, securityGroupObjectId, assignmentScope)
  properties: {
    roleDefinitionId: customRoleDefinition.id
    principalId: securityGroupObjectId
    principalType: 'Group'
    scope: assignmentScope
  }
}