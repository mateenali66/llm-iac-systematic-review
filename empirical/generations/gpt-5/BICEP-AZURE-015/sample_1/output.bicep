param location string = resourceGroup().location

@description('Name of the Log Analytics workspace.')
param logAnalyticsName string

@description('Log Analytics workspace SKU. Recommended: PerGB2018')
@allowed([
  'PerGB2018'
  'PerNode'
  'Standalone'
  'CapacityReservation'
])
param logAnalyticsSku string = 'PerGB2018'

@description('Number of days data will be retained in the workspace.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Daily ingestion quota in GB. Set -1 for unlimited.')
param dailyQuotaGb int = -1

@description('Tags applied to all resources.')
param tags object = {}

@description('Resource ID of the target AKS cluster to monitor.')
param aksResourceId string

@description('Name of the Azure Monitor action group.')
param actionGroupName string

@description('Short name for the action group (2-12 alphanumeric characters).')
@minLength(2)
@maxLength(12)
param actionGroupShortName string

@description('Email receivers for paging on-call engineers. Example: [{ name: "PrimaryOnCall", emailAddress: "oncall@example.com" }]')
param emailReceivers array = []

@description('SMS receivers for paging on-call engineers. Example: [{ name: "PrimarySMS", countryCode: "1", phoneNumber: "5551234567" }]')
param smsReceivers array = []

@description('Name of the CPU metric alert.')
param cpuAlertName string = 'aks-cpu-high-alert'

@description('CPU usage percentage threshold to trigger the alert.')
@minValue(1)
@maxValue(100)
param cpuThreshold float = 80

@description('Alert severity (0 = Sev0, 4 = Sev4).')
@allowed([
  0
  1
  2
  3
  4
])
param alertSeverity int = 2

@description('How often the alert is evaluated.')
@allowed([
  'PT1M'
  'PT2M'
  'PT5M'
  'PT10M'
  'PT15M'
])
param evaluationFrequency string = 'PT1M'

@description('Time window over which metrics are aggregated.')
@allowed([
  'PT5M'
  'PT10M'
  'PT15M'
  'PT30M'
  'PT1H'
])
param windowSize string = 'PT5M'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  sku: {
    name: logAnalyticsSku
  }
  properties: {
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2022-06-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [
      for e in emailReceivers: {
        name: string(e.name)
        emailAddress: string(e.emailAddress)
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: [
      for s in smsReceivers: {
        name: string(s.name)
        countryCode: string(s.countryCode)
        phoneNumber: string(s.phoneNumber)
      }
    ]
  }
}

resource cpuMetricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: cpuAlertName
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when AKS cluster average CPU usage exceeds threshold.'
    severity: alertSeverity
    enabled: true
    scopes: [
      aksResourceId
    ]
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          name: 'High CPU'
          metricNamespace: 'Microsoft.ContainerService/ManagedClusters'
          metricName: 'CPUUsagePercentage'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          threshold: cpuThreshold
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