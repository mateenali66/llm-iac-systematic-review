param location string = resourceGroup().location
param aksClusterName string
param aksResourceGroupName string
param logAnalyticsWorkspaceName string
param actionGroupName string
param alertName string
param emailReceiverName string
param emailReceiverAddress string

var aksClusterId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${aksResourceGroupName}/providers/Microsoft.ContainerService/managedClusters/${aksClusterName}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2021-02-01-preview' = {
  name: actionGroupName
  location: location
  properties: {
    groupShortName: actionGroupName
    enabled: true
    emailReceivers: [
      {
        name: emailReceiverName
        emailAddress: emailReceiverAddress
      }
    ]
  }
}

resource metricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: location
  properties: {
    description: 'CPU usage alert for AKS cluster'
    severity: 3
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      aksClusterId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'cpuUsagePercentage'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          operator: 'GreaterThan'
          threshold: 80
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}