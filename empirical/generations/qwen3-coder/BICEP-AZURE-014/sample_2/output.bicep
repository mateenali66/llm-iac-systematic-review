param roleName string = 'VM Reader'
param roleDescription string = 'Read-only access to virtual machines'
param securityGroupName string
param securityGroupEmail string

resource customRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, roleName)
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
      subscription().id
    ]
  }
}

resource securityGroup 'Microsoft.AzureActiveDirectory/b2cDirectories/guestUsages/invitations@2021-04-01-preview' = {
  name: securityGroupName
  properties: {
    displayName: securityGroupName
    mailNickname: securityGroupName
    mail: securityGroupEmail
    securityEnabled: true
    groupTypes: []
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, customRole.name, securityGroup.name)
  properties: {
    roleDefinitionId: customRole.id
    principalId: securityGroup.id
    principalType: 'Group'
  }
  scope: subscription()
}