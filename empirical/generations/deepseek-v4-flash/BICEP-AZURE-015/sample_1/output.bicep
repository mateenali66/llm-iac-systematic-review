param location string = resourceGroup().location
param aksClusterName string
param aksClusterResourceGroup string
param actionGroupShortName string = 'aks-cpu-pager'
param actionGroupEmail string
param actionGroupSmsCountryCode string
param actionGroupSmsPhoneNumber string
param workspaceName string = 'log-${uniqueString(resourceGroup().id)}'
param alertName string = 'aks-cpu-high-alert'
param alertDescription string = 'Alert when average CPU usage exceeds 80% for 5 minutes'
param cpuThreshold int = 80
param evaluationFrequency string = 'PT5M'
param windowSize string = 'PT5M'
param severity int = 1

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: 0.5
    }
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupShortName
  location: 'global'
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [
      {
        name: 'oncall-email'
        emailAddress: actionGroupEmail
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: [
      {
        name: 'oncall-sms'
        countryCode: actionGroupSmsCountryCode
        phoneNumber: actionGroupSmsPhoneNumber
      }
    ]
  }
}

resource metricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  properties: {
    description: alertDescription
    severity: severity
    enabled: true
    scopes: [
      resourceId('${aksClusterResourceGroup}', 'Microsoft.ContainerService/managedClusters', aksClusterName)
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