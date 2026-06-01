param location string = resourceGroup().location

resource vmReadOnlyRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('vm-read-only-role', subscription().id)
  properties: {
    roleName: 'Virtual Machine Reader'
    description: 'Read-only access to virtual machines and their resources'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/vmSizes/read'
          'Microsoft.Compute/virtualMachines/extensions/read'
          'Microsoft.Compute/virtualMachines/extensions/status/read'
          'Microsoft.Compute/availabilitySets/read'
          'Microsoft.Compute/disks/read'
          'Microsoft.Compute/snapshots/read'
          'Microsoft.Compute/images/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/read'
          'Microsoft.Network/networkInterfaces/effectiveRouteTable/read'
          'Microsoft.Network/networkInterfaces/ipConfigurations/read'
          'Microsoft.Network/networkInterfaces/loadBalancers/read'
          'Microsoft.Network/networkInterfaces/tapConfigurations/read'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/virtualNetworks/subnets/read'
          'Microsoft.Network/loadBalancers/read'
          'Microsoft.Network/loadBalancers/backendAddressPools/read'
          'Microsoft.Network/loadBalancers/frontendIPConfigurations/read'
          'Microsoft.Network/loadBalancers/inboundNatRules/read'
          'Microsoft.Network/loadBalancers/loadBalancingRules/read'
          'Microsoft.Network/loadBalancers/outboundRules/read'
          'Microsoft.Network/loadBalancers/probes/read'
          'Microsoft.Network/networkSecurityGroups/read'
          'Microsoft.Network/networkSecurityGroups/securityRules/read'
          'Microsoft.Storage/storageAccounts/read'
          'Microsoft.Storage/storageAccounts/blobServices/read'
          'Microsoft.Storage/storageAccounts/fileServices/read'
          'Microsoft.Storage/storageAccounts/queueServices/read'
          'Microsoft.Storage/storageAccounts/tableServices/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Resources/tags/read'
          'Microsoft.Resources/deployments/read'
          'Microsoft.ResourceHealth/availabilityStatuses/read'
          'Microsoft.Insights/Metrics/Read'
          'Microsoft.Insights/MetricDefinitions/Read'
          'Microsoft.Insights/DiagnosticSettings/Read'
          'Microsoft.Insights/LogDefinitions/Read'
          'Microsoft.OperationalInsights/workspaces/read'
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

@description('The object ID of the security group to assign the role to')
param securityGroupObjectId string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(securityGroupObjectId, vmReadOnlyRoleDefinition.name, subscription().id)
  properties: {
    roleDefinitionId: vmReadOnlyRoleDefinition.id
    principalId: securityGroupObjectId
    principalType: 'Group'
  }
}