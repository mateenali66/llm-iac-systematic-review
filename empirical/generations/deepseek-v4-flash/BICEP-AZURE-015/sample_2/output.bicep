param location string = resourceGroup().location
param aksClusterName string
param aksClusterResourceGroup string
param actionGroupShortName string = 'aks-cpu-pager'
param actionGroupName string = 'aks-cpu-pager-ag'
param emailReceiverName string = 'oncall-email'
param emailAddress string
param smsReceiverName string = 'oncall-sms'
param smsCountryCode string
param smsPhoneNumber string
param webhookReceiverName string = 'oncall-pagerduty'
param webhookUri string
param logAnalyticsWorkspaceName string = 'aks-logs-${uniqueString(resourceGroup().id)}'
param alertName string = 'aks-cpu-high'
param alertDescription string = 'Alert when average CPU usage on AKS cluster exceeds 80% for 5 minutes'
param cpuThreshold int = 80
param evaluationFrequency string = 'PT5M'
param windowSize string = 'PT5M'
param severity int = 1

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [
      {
        name: emailReceiverName
        emailAddress: emailAddress
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: [
      {
        name: smsReceiverName
        countryCode: smsCountryCode
        phoneNumber: smsPhoneNumber
      }
    ]
    webhookReceivers: [
      {
        name: webhookReceiverName
        serviceUri: webhookUri
        useCommonAlertSchema: true
      }
    ]
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-08-01' existing = {
  name: aksClusterName
  scope: resourceGroup(aksClusterResourceGroup)
}

resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  properties: {
    description: alertDescription
    severity: severity
    enabled: true
    scopes: [
      aksCluster.id
    ]
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'cpuMetric'
          metricName: 'cpuUsagePercentage'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
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
        webHookProperties: {}
      }
    ]
  }
}