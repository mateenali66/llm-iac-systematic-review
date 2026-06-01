@description('Location for all resources')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

@description('Environment name used in naming')
param environment string = 'prod'

@description('Log Analytics Workspace name')
param workspaceName string = 'log-${environment}-${uniqueString(resourceGroup().id)}'

@description('Log retention in days (30-730)')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('Public network access for ingestion: Enabled or Disabled')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccessForIngestion string = 'Enabled'

@description('Public network access for query: Enabled or Disabled')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccessForQuery string = 'Enabled'

@description('Action Group resource name')
param actionGroupName string = 'ag-${environment}-${uniqueString(resourceGroup().id)}'

@description('Short name for the Action Group (max 12 chars)')
param actionGroupShortName string = 'oncall'

@description('Email receivers for the action group')
param emailReceivers array = [
  {
    name: 'OnCallPrimary'
    emailAddress: 'oncall@example.com'
  }
]

@description('SMS receivers for the action group (objects with name, countryCode, phoneNumber)')
param smsReceivers array = []

@description('Webhook receivers for the action group (objects with name, serviceUri)')
param webhookReceivers array = []

@description('Resource ID of the target AKS cluster to monitor')
param aksResourceId string

@description('CPU threshold percentage to trigger alert')
@minValue(1)
@maxValue(100)
param cpuThreshold float = 80.0

@description('Alert evaluation frequency (ISO8601 duration, e.g., PT5M)')
param evaluationFrequency string = 'PT5M'

@description('Alert window size (ISO8601 duration, e.g., PT15M)')
param windowSize string = 'PT15M'

@description('Metric namespace for the AKS cluster CPU metric')
param metricNamespace string = 'microsoft.containerservice/managedclusters'

@description('Metric name for AKS CPU usage')
param metricName string = 'node_cpu_usage_percentage'

@description('Metric alert severity (0-4)')
@minValue(0)
@maxValue(4)
param alertSeverity int = 2

@description('Metric alert resource name')
param alertName string = 'aks-highcpu-alert'

resource laWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  sku: {
    name: 'PerGB2018'
  }
  properties: {
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [for e in emailReceivers: {
      name: string(e.name)
      emailAddress: string(e.emailAddress)
      useCommonAlertSchema: true
    }]
    smsReceivers: [for s in smsReceivers: {
      name: string(s.name)
      countryCode: string(s.countryCode)
      phoneNumber: string(s.phoneNumber)
    }]
    webhookReceivers: [for w in webhookReceivers: {
      name: string(w.name)
      serviceUri: string(w.serviceUri)
      useCommonAlertSchema: true
    }]
  }
}

resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  properties: {
    description: 'Alert when AKS cluster CPU usage exceeds threshold'
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
          name: 'HighCPU'
          metricName: metricName
          metricNamespace: metricNamespace
          operator: 'GreaterThan'
          threshold: cpuThreshold
          timeAggregation: 'Average'
          dimensions: []
          skipMetricValidation: true
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

output logAnalyticsWorkspaceId string = laWorkspace.id
output actionGroupId string = actionGroup.id
output metricAlertId string = cpuAlert.id