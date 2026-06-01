param location string = resourceGroup().location
param securityGroupObjectId string
param roleName string = 'Virtual Machine Reader'
param roleDescription string = 'Custom role granting read-only access to virtual machines'

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(roleName, subscription().id)
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/vmSizes/read'
          'Microsoft.Compute/locations/vmSizes/read'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/networkInterfaces/ipConfigurations/read'
          'Microsoft.Network/publicIPAddresses/read'
          'Microsoft.Storage/storageAccounts/read'
          'Microsoft.Storage/storageAccounts/blobServices/read'
          'Microsoft.Storage/storageAccounts/blobServices/containers/read'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Resources/subscriptions/resourceGroups/resources/read'
          'Microsoft.ResourceHealth/availabilityStatuses/read'
          'Microsoft.Insights/alertRules/read'
          'Microsoft.Insights/diagnosticSettings/read'
          'Microsoft.Insights/metricDefinitions/read'
          'Microsoft.Insights/metrics/read'
          'Microsoft.Insights/logs/read'
          'Microsoft.Insights/eventtypes/read'
          'Microsoft.Insights/eventCategories/read'
          'Microsoft.Insights/activityLogAlerts/read'
          'Microsoft.Insights/activityLogs/read'
          'Microsoft.Insights/dataCollectionRules/read'
          'Microsoft.Insights/dataCollectionEndpoints/read'
          'Microsoft.Insights/dataCollectionRuleAssociations/read'
          'Microsoft.OperationalInsights/workspaces/read'
          'Microsoft.OperationalInsights/workspaces/query/read'
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

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(roleDefinition.name, securityGroupObjectId, subscription().id)
  properties: {
    roleDefinitionId: roleDefinition.id
    principalId: securityGroupObjectId
    principalType: 'Group'
  }
}