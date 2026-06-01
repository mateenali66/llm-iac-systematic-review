@description('Location for all resources.')
param location string = resourceGroup().location

@description('Environment name used for tagging and naming.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'prod'

@description('Base name used to construct resource names.')
@minLength(3)
@maxLength(20)
param baseName string = 'platform'

@description('Resource ID of the AKS cluster to monitor.')
param aksClusterResourceId string

@description('Retention in days for Log Analytics workspace.')
@minValue(30)
@maxValue(730)
param logRetentionInDays int = 90

@description('Daily ingestion cap in GB for Log Analytics (-1 for unlimited).')
param dailyQuotaGb int = -1

@description('SKU for Log Analytics workspace.')
@allowed([
  'PerGB2018'
  'CapacityReservation'
])
param logAnalyticsSku string = 'PerGB2018'

@description('Short name (max 12 chars) for the action group used in SMS/voice.')
@maxLength(12)
param actionGroupShortName string = 'OnCallPage'

@description('On-call engineer email addresses for paging.')
param onCallEmails array = []

@description('On-call engineer SMS contacts. Each item: { name, countryCode, phoneNumber }.')
param onCallSms array = []

@description('On-call engineer voice contacts. Each item: { name, countryCode, phoneNumber }.')
param onCallVoice array = []

@description('Optional webhook receivers (e.g., PagerDuty/Opsgenie). Each item: { name, serviceUri, useCommonAlertSchema }.')
param webhookReceivers array = []

@description('CPU usage percentage threshold to trigger the alert.')
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
param evaluationFrequency string = 'PT5M'

@description('Alert window size (ISO 8601 duration).')
@allowed([
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
  'PT6H'
  'PT12H'
  'P1D'
])
param windowSize string = 'PT15M'

@description('Severity of the alert. 0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose.')
@allowed([
  0
  1
  2
  3
  4
])
param alertSeverity int = 1

var commonTags = {
  environment: environment
  workload: baseName
  managedBy: 'bicep'
}

var workspaceName = 'log-${baseName}-${environment}-${uniqueString(resourceGroup().id)}'
var actionGroupName = 'ag-${baseName}-${environment}-oncall'
var alertName = 'alert-${baseName}-${environment}-aks-cpu-high'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: logRetentionInDays
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: false
    }
  }
}

resource onCallActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: commonTags
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [for (email, i) in onCallEmails: {
      name: 'email-${i}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
    smsReceivers: [for (sms, i) in onCallSms: {
      name: 'sms-${sms.name}'
      countryCode: sms.countryCode
      phoneNumber: sms.phoneNumber
    }]
    voiceReceivers: [for (voice, i) in onCallVoice: {
      name: 'voice-${voice.name}'
      countryCode: voice.countryCode
      phoneNumber: voice.phoneNumber
    }]
    webhookReceivers: [for (wh, i) in webhookReceivers: {
      name: wh.name
      serviceUri: wh.serviceUri
      useCommonAlertSchema: contains(wh, 'useCommonAlertSchema') ? wh.useCommonAlertSchema : true
    }]
  }
}

resource aksCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  tags: commonTags
  properties: {
    description: 'High node CPU usage detected on AKS cluster ${last(split(aksClusterResourceId, '/'))}.'
    severity: alertSeverity
    enabled: true
    scopes: [
      aksClusterResourceId
    ]
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    targetResourceRegion: location
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'NodeCpuUsagePercentage'
          metricNamespace: 'Microso