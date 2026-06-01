@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name used in resource naming and tagging.')
@allowed([
  'dev'
  'test'
  'staging'
  'prod'
])
param environment string = 'prod'

@description('Workload or application name used in resource naming.')
@minLength(2)
@maxLength(16)
param workloadName string = 'platform'

@description('Resource ID of the AKS cluster to monitor.')
param aksClusterResourceId string

@description('Retention in days for the Log Analytics workspace.')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionInDays int = 90

@description('Daily ingestion cap in GB for the Log Analytics workspace. Use -1 for no cap.')
param logAnalyticsDailyQuotaGb int = -1

@description('SKU for the Log Analytics workspace.')
@allowed([
  'PerGB2018'
  'CapacityReservation'
])
param logAnalyticsSku string = 'PerGB2018'

@description('CPU percentage threshold that triggers the alert.')
@minValue(1)
@maxValue(100)
param cpuThresholdPercent int = 80

@description('Alert evaluation frequency (ISO 8601 duration).')
@allowed([
  'PT1M'
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
])
param alertEvaluationFrequency string = 'PT5M'

@description('Alert evaluation window size (ISO 8601 duration).')
@allowed([
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
  'PT6H'
  'PT12H'
  'P1D'
])
param alertWindowSize string = 'PT15M'

@description('Severity of the metric alert. 0 = Critical, 4 = Verbose.')
@allowed([
  0
  1
  2
  3
  4
])
param alertSeverity int = 1

@description('On-call engineer contacts to notify via email and SMS.')
param onCallContacts array = []

@description('Optional webhook receivers (e.g., PagerDuty, OpsGenie, ServiceNow).')
param webhookReceivers array = []

@description('Tags applied to all resources.')
param tags object = {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
}

var uniqueSuffix = uniqueString(resourceGroup().id, workloadName, environment)
var logAnalyticsName = 'log-${workloadName}-${environment}-${uniqueSuffix}'
var actionGroupName = 'ag-${workloadName}-${environment}-oncall'
var actionGroupShortName = take(toLower('${workloadName}${environment}'), 12)
var metricAlertName = 'alert-aks-cpu-${workloadName}-${environment}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: logAnalyticsRetentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: false
    }
    workspaceCapping: {
      dailyQuotaGb: logAnalyticsDailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [for (contact, i) in onCallContacts: {
      name: 'email-${contact.name}'
      emailAddress: contact.email
      useCommonAlertSchema: true
    }]
    smsReceivers: [for (contact, i) in onCallContacts: if (contains(contact, 'countryCode') && contains(contact, 'phoneNumber')) {
      name: 'sms-${contact.name}'
      countryCode: contact.countryCode
      phoneNumber: contact.phoneNumber
    }]
    voiceReceivers: [for (contact, i) in onCallContacts: if (contains(contact, 'countryCode') && contains(contact, 'phoneNumber')) {
      name: 'voice-${contact.name}'
      countryCode: contact.countryCode
      phoneNumber: contact.phoneNumber
    }]
    webhookReceivers: [for (hook, i) in webhookReceivers: {
      name: hook.name
      serviceUri: hook.serviceUri
      useCommonAlertSchema: true
      useAadAuth: contains(hook, 'useAadAuth') ? hook.useAadAuth : false
    }]
  }
}

resource aksCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: metricAlertName
  location: 'global'
  tags: tags
  properties: {
    description: 'Alerts when average node CPU usage on AKS cluster exceeds ${cpuThresholdPercent}% over ${alertWindowSize}.'
    severity: alertSeverity
    enabled: true
    scopes: [
      aksClusterResourceId
    ]
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    evaluationFrequency: alertEvaluationFrequency
    windowSize: alertWindowSize
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Nod