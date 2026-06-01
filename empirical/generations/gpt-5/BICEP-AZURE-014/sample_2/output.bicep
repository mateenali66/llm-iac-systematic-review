targetScope = 'subscription'

@description('Object ID of the Entra ID security group to assign the role to.')
@minLength(1)
param groupObjectId string

@description('Scope at which to assign the role (e.g., subscription id or specific resource group/resource id). Must be within one of the assignableScopes.')
param assignmentScope string = subscription().id

@description('Assignable scopes for the custom role. Defaults to the current subscription.')
param assignableScopes array = [
  subscription().id
]

@description('Display name for the custom role.')
param roleName string = 'VM Read Only - Custom'

@description('Description for the custom role.')
param roleDescription string = 'Provides read-only access to view virtual machines and related networking and compute metadata.'

@description('Stable GUID for the custom role definition resource name. Provide to ensure idempotent updates across deployments.')
param roleDefinitionGuid string = guid(subscription().id, 'vm-read-only-custom-role')

resource customRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionGuid
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/availabilitySets/read'
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/extensions/read'
          'Microsoft.Compute/virtualMachineScaleSets/read'
          'Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read'
          'Microsoft.Compute/virtualMachineScaleSets/virtualMachines/instanceView/read'
          'Microsoft.Compute/disks/read'
          'Microsoft.Compute/snapshots/read'
          'Microsoft.Compute/images/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Network/networkSecurityGroups/read'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/virtualNetworks/subnets/read'
          'Microsoft.Network/loadBalancers/read'
          'Microsoft.Network/applicationSecurityGroups/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Resources/subscriptions/resources/read'
          'Microsoft.Insights/diagnosticSettings/read'
          'Microsoft.Insights/metricDefinitions/read'
          'Microsoft.Insights/metrics/read'
          'Microsoft.Authorization/locks/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: assignableScopes
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(assignmentScope, groupObjectId, roleDefinitionGuid)
  scope: assignmentScope
  properties: {
    roleDefinitionId: customRole.id
    principalId: groupObjectId
    principalType: 'Group'
  }
}

output customRoleId string = customRole.id
output roleAssignmentId string = roleAssignment.id