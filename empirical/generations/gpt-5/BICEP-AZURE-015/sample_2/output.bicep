param location string = resourceGroup().location
param tags object = {
  environment: 'prod'
}
param workspaceName string = toLower('law-${uniqueString(resourceGroup().id)}')
param workspaceRetentionDays int = 30
@allowed([
  'PerGB2018'
  'PerNode'
  'Free'
  'Standalone'
  'CapacityReservation'
  'LACluster'
])
param workspaceSku string = 'PerGB2018'
@minValue(-1)
param workspaceDailyQuotaGb int = -1

@description('Resource ID of the target AKS cluster to monitor')
param aksResourceId string

@maxLength(12)
param actionGroupShortName string = 'oncall'
param actionGroupName string = 'oncall-actiongroup'
@description('List of on-call emails to notify')
param onCallEmails array = [
  'oncall@example.com'
]
@description('List of on-call SMS recipients as objects with countryCode and phoneNumber')
param onCallSms array = [
  {
    countryCode: '1'
    phoneNumber: '5551234567'
  }
]

@description('Metric alert rule name')
param alertRuleName string = 'aks-cpu-usage-alert'
@description('Severity 0 (critical) to 4 (verbose)')
@allowed([0, 1, 2, 3, 4])
param alertSeverity int = 2
@description('Static threshold for CPU usage percentage')
@paramMinValue(1)
@paramMaxValue(100)
param cpuThreshold int = 80
@description('Frequency to evaluate the alert, e.g., PT5M')
param evaluationFrequency string = 'PT5M'
@description('Time window over which to aggregate, e.g., PT15M')
param windowSize string = 'PT15M'
@description('Operator for threshold comparison')
@allowed([
  'GreaterThan'
  'GreaterThanOrEqual'
  'LessThan'
  'LessThanOrEqual'
])
param comparisonOperator string = 'GreaterThan'
@description('Aggregation for the metric')
@allowed([
  'Average'
  'Minimum'
  'Maximum'
  'Total'
  'Count'
])
param timeAggregation string = 'Average'
@description('Metric namespace. For AKS CPU via Container Insights use insights.container/nodes; for platform metrics use Microsoft.ContainerService/managedClusters with an appropriate metricName.')
param metricNamespace string = 'insights.container/nodes'
@description('Metric name. For Container Insights CPU use cpuUsagePercentage.')
param metricName string = 'cpuUsagePercentage'

var emailReceivers = [for (email, i) in onCallEmails: {
  name: 'emailReceiver${i + 1}'
  emailAddress: string(email)
  useCommonAlertSchema: true
}]
var smsReceivers = [for (s, i) in onCallSms: {
  name: 'smsReceiver${i + 1}'
  countryCode: string(s.countryCode)
  phoneNumber: string(s.phoneNumber)
}]

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  sku: {
    name: workspaceSku
  }
  properties: {
    retentionInDays: workspaceRetentionDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: workspaceDailyQuotaGb
    }
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2022-06-15' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    groupShortName: actionGroupShortName
    emailReceivers: emailReceivers
    smsReceivers: smsReceivers
  }
}

resource cpuMetricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertRuleName
  location: 'global'
  tags: tags
  properties: {
    description: 'High CPU usage detected on AKS cluster'
    severity: alertSeverity
    enabled: true
    scopes: [
      aksResourceId
    ]
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'High CPU'
          metricNamespace: metricNamespace
          metricName: metricName
          operator: comparisonOperator
          threshold: cpuThreshold
          timeAggregation: timeAggregation
          dimensions: []
          skipMetricValidation: true
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