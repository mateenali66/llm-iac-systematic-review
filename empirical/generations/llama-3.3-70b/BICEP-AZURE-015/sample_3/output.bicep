param location string = resourceGroup().location
param aksClusterName string
param aksResourceGroupName string
param logAnalyticsWorkspaceName string
param actionGroupName string
param alertName string
param emailReceiverName string
param emailReceiverAddress string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-11-01' = existing(resourceId(aksResourceGroupName, 'Microsoft.ContainerService/managedClusters', aksClusterName))

resource actionGroup 'Microsoft.Insights/actionGroups@2021-08-01' = {
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
      aksCluster.id
    ]
    criteria: {
      allOf: [
        {
          metricName: 'cpuUsagePercentage'
          metricNamespace: 'microsoft.containerservice/managedclusters'
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