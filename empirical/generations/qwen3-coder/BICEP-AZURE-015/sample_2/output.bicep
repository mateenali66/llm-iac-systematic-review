param location string = resourceGroup().location
param workspaceName string = 'law-${uniqueString(resourceGroup().id)}'
param actionGroupName string = 'ag-paging'
param aksClusterId string
param cpuThreshold int = 80
param alertSeverity int = 1

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

resource actionGroup 'Microsoft.Insights/actionGroups@2023-03-01' = {
  name: actionGroupName
  location: 'Global'
  properties: {
    groupShortName: 'oncall'
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
        name: 'AdminRole'
        roleId: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner role
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
    severity: alertSeverity
    enabled: true
    scopes: [
      aksClusterId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'allOf': [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'CPUUsage'
          metricName: 'cpuUsage'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          operator: 'GreaterThan'
          threshold: cpuThreshold
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

output workspaceId string = logAnalyticsWorkspace.id
output actionGroupId string = actionGroup.id
output alertId string = cpuAlert.id