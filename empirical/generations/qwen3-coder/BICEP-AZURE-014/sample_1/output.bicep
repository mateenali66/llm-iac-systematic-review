param roleName string = 'VM Reader'
param roleDescription string = 'Read-only access to virtual machines'
param securityGroupName string
param subscriptionId string = subscription().subscriptionId

resource customRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscriptionId, roleName)
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/extensions/read'
          'Microsoft.Compute/virtualMachines/extensions/*/read'
          'Microsoft.Compute/virtualMachines/login/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/networkSecurityGroups/read'
          'Microsoft.Storage/storageAccounts/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
        ]
        notActions: []
      }
    ]
    assignableScopes: [
      subscriptionResourceId('Microsoft.Resources/subscriptions', subscriptionId)
    ]
  }
}

resource securityGroup 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, securityGroupName, customRole.name)
  properties: {
    roleDefinitionId: customRole.id
    principalId: reference(resourceId('Microsoft.Management/managementGroups', securityGroupName), '2021-04-01').id
    principalType: 'Group'
  }
  dependsOn: [
    customRole
  ]
}