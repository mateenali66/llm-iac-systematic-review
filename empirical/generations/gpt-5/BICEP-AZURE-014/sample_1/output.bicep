targetScope = 'subscription'

param roleName string = 'Virtual Machine Reader (Custom)'
param targetRgName string
param securityGroupObjectId string

var roleDefinitionGuid = guid(subscription().id, roleName, 'vm-readonly-custom')

resource vmReadOnlyRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionGuid
  properties: {
    roleName: roleName
    description: 'Provides read-only access to Azure Virtual Machines and related resources at the resource group scope.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/availabilitySets/read'
          'Microsoft.Compute/disks/read'
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/extensions/read'
          'Microsoft.Compute/virtualMachineScaleSets/read'
          'Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read'
          'Microsoft.Compute/virtualMachineScaleSets/virtualMachines/instanceView/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/networkSecurityGroups/read'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/loadBalancers/read'
          'Microsoft.Insights/metricDefinitions/read'
          'Microsoft.Insights/metrics/read'
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

resource targetRg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: targetRgName
}

resource sgRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(targetRg.id, securityGroupObjectId, vmReadOnlyRole.id)
  scope: targetRg
  properties: {
    roleDefinitionId: vmReadOnlyRole.id
    principalId: securityGroupObjectId
    principalType: 'Group'
  }
}