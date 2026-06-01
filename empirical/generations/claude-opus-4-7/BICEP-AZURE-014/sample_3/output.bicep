targetScope = 'subscription'

@description('Object ID of the Azure AD security group to assign the custom role to.')
param securityGroupObjectId string

@description('Name of the custom RBAC role.')
param customRoleName string = 'Virtual Machine Read-Only'

@description('Description of the custom RBAC role.')
param customRoleDescription string = 'Provides read-only access to virtual machines and related resources.'

@description('Subscription IDs where this role definition is assignable.')
param assignableScopes array = [
  subscription().id
]

var roleDefinitionId = guid(subscription().id, customRoleName)
var roleAssignmentId = guid(subscription().id, securityGroupObjectId, roleDefinitionId)

resource vmReadOnlyRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionId
  properties: {
    roleName: customRoleName
    description: customRoleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/extensions/read'
          'Microsoft.Compute/virtualMachineScaleSets/read'
          'Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read'
          'Microsoft.Compute/availabilitySets/read'
          'Microsoft.Compute/disks/read'
          'Microsoft.Compute/snapshots/read'
          'Microsoft.Compute/images/read'
          'Microsoft.Compute/locations/operations/read'
          'Microsoft.Compute/locations/vmSizes/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/networkSecurityGroups/read'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/virtualNetworks/subnets/read'
          'Microsoft.Storage/storageAccounts/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: assignableScopes
  }
}

resource vmReadOnlyRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentId
  properties: {
    roleDefinitionId: vmReadOnlyRole.id
    principalId: securityGroupObjectId
    principalType: 'Group'
    description: 'Grants read-only VM access to the specified security group.'
  }
}

output roleDefinitionId string = vmReadOnlyRole.id
output roleDefinitionName string = vmReadOnlyRole.name
output roleAssignmentId string = vmReadOnlyRoleAssignment.id