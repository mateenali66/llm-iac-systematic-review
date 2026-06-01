param location string = resourceGroup().location
param workspaceName string = 'law-${uniqueString(resourceGroup().id)}'
param actionGroupName string = 'ag-paging'
param aksClusterName string = 'aks-cluster'
param aksResourceGroup string = resourceGroup().name

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
    groupShortName: 'paging'
    enabled: true
    emailReceivers: []
    smsReceivers: []
    webhookReceivers: []
    itsmReceivers: []
    azureAppPushReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceiver: [
      {
        name: 'oncall-engineer'
        roleId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role
        useCommonAlertSchema: true
      }
    ]
  }
}

resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'aks-cpu-alert'
  location: 'Global'
  properties: {
    description: 'Alert when AKS cluster CPU usage exceeds threshold'
    severity: 3
    enabled: true
    scopes: [
      resourceId('Microsoft.ContainerService/managedClusters', aksClusterName)
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'allOf': [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'CPUUsage'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          metricName: 'cpuUsagePercentage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
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