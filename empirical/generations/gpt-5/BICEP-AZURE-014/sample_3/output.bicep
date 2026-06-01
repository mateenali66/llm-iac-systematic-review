targetScope = 'resourceGroup'

@description('Display name for the custom role.')
param roleName string = 'VM Read Only'

@description('Description for the custom role.')
param roleDescription string = 'Read-only access to view Azure Virtual Machines and key related resources (network interfaces, IPs, disks) without any modification permissions.'

@description('Object ID of the Microsoft Entra ID security group to assign the role to.')
param principalObjectId string

var roleDefinitionGuid = guid(subscription().id, roleName)

resource vmReadOnlyRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionGuid
  scope: subscription()
  properties: {
    roleName: roleName
    description: roleDescription
    roleType: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/extensions/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/availabilitySets/read'
          'Microsoft.Compute/virtualMachineScaleSets/read'
          'Microsoft.Compute/locations/*/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Network/networkSecurityGroups/read'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/virtualNetworks/subnets/read'
          'Microsoft.Network/loadBalancers/read'
          'Microsoft.Network/applicationGateways/read'
          'Microsoft.Compute/disks/read'
          'Microsoft.Compute/snapshots/read'
          'Microsoft.Insights/metrics/read'
          'Microsoft.Insights/metricDefinitions/read'
          'Microsoft.Authorization/locks/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Resources/tags/read'
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

resource vmReadOnlyAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalObjectId, roleDefinitionGuid)
  properties: {
    roleDefinitionId: vmReadOnlyRole.id
    principalId: principalObjectId
    principalType: 'Group'
  }
}