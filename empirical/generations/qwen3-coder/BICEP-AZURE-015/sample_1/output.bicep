param location string = resourceGroup().location
param workspaceName string = 'law-${uniqueString(resourceGroup().id)}'
param actionGroupName string = 'ag-paging'
param aksClusterName string = 'aks-cluster'
param alertName string = 'aks-cpu-alert'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  properties: {
    groupShortName: 'oncall'
    enabled: true
    emailReceivers: [
      {
        name: 'oncall-engineer'
        emailAddress: 'oncall@company.com'
      }
    ]
    smsReceivers: [
      {
        name: 'sms-oncall'
        countryCode: '1'
        phoneNumber: '5551234567'
      }
    ]
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-02-01' existing = {
  name: aksClusterName
}

resource metricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  properties: {
    description: 'Alert when AKS cluster CPU usage exceeds threshold'
    severity: 2
    enabled: true
    scopes: [
      aksCluster.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'allOf': [
        {
          name: 'CPUUsage'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          metricName: 'node_cpu_usage_percentage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          dimensions: []
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