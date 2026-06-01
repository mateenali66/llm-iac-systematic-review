targetScope = 'subscription'

@description('Name of the custom role definition.')
param roleName string = 'VM Read-Only Operator'

@description('Description of the custom role definition.')
param roleDescription string = 'Provides read-only access to Azure Virtual Machines and related resources.'

@description('Object ID (principal ID) of the Microsoft Entra ID security group to assign the role to.')
param securityGroupObjectId string

@description('Array of subscription IDs where this role can be assigned. Defaults to the current subscription.')
param assignableScopes array = [
  subscription().id
]

var roleDefinitionId = guid(subscription().id, roleName)
var roleAssignmentId = guid(subscription().id, securityGroupObjectId, roleDefinitionId)

resource customRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionId
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
          'Microsoft.Compute/skus/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/networkSecurityGroups/read'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/virtualNetworks/subnets/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Resources/subscriptions/read'
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

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentId
  properties: {
    roleDefinitionId: customRole.id
    principalId: securityGroupObjectId
    principalType: 'Group'
    description: 'Grants the security group read-only access to virtual machines.'
  }
}

output roleDefinitionId string = customRole.id
output roleDefinitionName string = customRole.properties.roleName
output roleAssignmentId string = roleAssignment.id