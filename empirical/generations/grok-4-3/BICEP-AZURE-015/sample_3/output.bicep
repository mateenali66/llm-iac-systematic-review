@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the Log Analytics workspace')
param workspaceName string

@description('Name of the Azure Monitor action group')
param actionGroupName string

@description('Email address for on-call engineers')
param onCallEmail string

@description('Name of the existing AKS cluster')
param aksClusterName string

@description('Name of the CPU metric alert')
param alertName string = 'aks-cpu-alert'

@description('CPU usage percentage threshold for the alert')
param cpuThreshold int = 80

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  properties: {
    groupShortName: substring(actionGroupName, 0, min(length(actionGroupName), 12))
    enabled: true
    emailReceivers: [
      {
        name: 'oncall-email'
        emailAddress: onCallEmail
      }
    ]
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' existing = {
  name: aksClusterName
}

resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  properties: {
    description: 'Alert when AKS cluster CPU usage exceeds threshold'
    severity: 1
    enabled: true
    scopes: [
      aksCluster.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'CPUUsage'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          metricName: 'cpuUsagePercentage'
          operator: 'GreaterThan'
          threshold: cpuThreshold
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
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