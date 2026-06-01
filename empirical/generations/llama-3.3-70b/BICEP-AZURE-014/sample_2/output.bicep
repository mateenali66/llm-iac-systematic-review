param securityGroupName string = 'ReadOnlyVMAccessGroup'
param roleDefinitionName string = 'CustomReadOnlyVMRole'
param location string = resourceGroup().location

var roleDefinition = {
  'Name': roleDefinitionName
  'Description': 'Read-only access to virtual machines'
  'Actions': [
    'Microsoft.Compute/virtualMachines/read'
    'Microsoft.Compute/virtualMachines/*/read'
    'Microsoft.Compute/virtualMachines/instanceView/read'
    'Microsoft.Compute/virtualMachines/vmSizes/read'
  ]
  'NotActions': [
  ]
  'DataActions': [
  ]
  'NotDataActions': [
  ]
  'AssignableScopes': [
    '/subscriptions/${subscription().subscriptionId}'
  ]
}

resource roleDefinitionResource 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
  name: roleDefinitionName
  properties: roleDefinition
}

resource securityGroup 'Microsoft.Graph/group@1.1' existing = {
  name: securityGroupName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(securityGroupName, roleDefinitionName)
  properties: {
    principalId: securityGroup.properties.id
    principalType: 'Group'
    roleDefinitionId: roleDefinitionResource.id
  }
}