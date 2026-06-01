targetScope = 'subscription'

@description('Name of the custom role')
param roleName string = 'VM Read-Only Operator'

@description('Description of the custom role')
param roleDescription string = 'Custom role granting read-only access to Azure Virtual Machines and related resources.'

@description('Object ID of the Azure AD security group to assign the role to')
param securityGroupObjectId string

@description('Subscription IDs where this role can be assigned')
param assignableScopes array = [
  subscription().id
]

var roleDefinitionName = guid(subscription().id, roleName)
var roleAssignmentName = guid(subscription().id, securityGroupObjectId, roleDefinitionName)

resource vmReadOnlyRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionName
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/extensions/read'
          'Microsoft.Compute/virtualMachineScaleSets/read'
          'Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read'
          'Microsoft.Compute/virtualMachineScaleSets/virtualMachines/instanceView/read'
          'Microsoft.Compute/availabilitySets/read'
          'Microsoft.Compute/disks/read'
          'Microsoft.Compute/snapshots/read'
          'Microsoft.Compute/images/read'
          'Microsoft.Compute/locations/usages/read'
          'Microsoft.Compute/locations/vmSizes/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/networkSecurityGroups/read'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/virtualNetworks/subnets/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Insights/metrics/read'
          'Microsoft.Insights/metricDefinitions/read'
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
  name: roleAssignmentName
  properties: {
    roleDefinitionId: vmReadOnlyRole.id
    principalId: securityGroupObjectId
    principalType: 'Group'
    description: 'Grants read-only VM access to the specified security group'
  }
}

output roleDefinitionId string = vmReadOnlyRole.id
output roleDefinitionName string = vmReadOnlyRole.properties.roleName
output roleAssignmentId string = vmReadOnlyRoleAssignment.id