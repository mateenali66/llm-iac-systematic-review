@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name used for tagging and naming.')
@allowed([
  'dev'
  'test'
  'staging'
  'prod'
])
param environment string = 'prod'

@description('Workload or application short name used in resource naming.')
@minLength(2)
@maxLength(10)
param workloadName string = 'platform'

@description('Resource ID of the existing AKS cluster to monitor.')
param aksClusterResourceId string

@description('Log Analytics workspace retention in days.')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionInDays int = 90

@description('Log Analytics workspace daily ingestion cap in GB. -1 means no cap.')
param dailyQuotaGb int = -1

@description('Primary on-call email address for paging.')
param oncallEmail string

@description('Secondary on-call email address (optional).')
param secondaryOncallEmail string = ''

@description('On-call SMS country code (e.g., 1 for US).')
param oncallSmsCountryCode string = '1'

@description('On-call SMS phone number (digits only, no dashes or spaces).')
param oncallSmsPhoneNumber string

@description('Webhook URI for integration with paging system (e.g., PagerDuty, Opsgenie). Leave empty to disable.')
param pagingWebhookUri string = ''

@description('CPU usage percent threshold that triggers the alert.')
@minValue(1)
@maxValue(100)
param cpuThresholdPercent int = 80

@description('Alert evaluation frequency in ISO 8601 duration format.')
@allowed([
  'PT1M'
  'PT5M'
  'PT15M'
])
param alertEvaluationFrequency string = 'PT1M'

@description('Alert window size in ISO 8601 duration format.')
@allowed([
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
])
param alertWindowSize string = 'PT5M'

@description('Alert severity. 0 = Critical, 1 = Error, 2 = Warning, 3 = Informational, 4 = Verbose.')
@allowed([
  0
  1
  2
  3
  4
])
param alertSeverity int = 1

@description('Common resource tags.')
param tags object = {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
  costCenter: 'platform-ops'
}

var namePrefix = toLower('${workloadName}-${environment}')
var logAnalyticsWorkspaceName = 'log-${namePrefix}-${uniqueString(resourceGroup().id)}'
var actionGroupName = 'ag-${namePrefix}-oncall'
var actionGroupShortName = take('oncall${take(environment, 3)}', 12)
var cpuAlertName = 'alert-${namePrefix}-aks-cpu-high'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logAnalyticsRetentionInDays
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

resource actionGroup 'Insights/actionGroups@2023-09-01-preview' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: concat([
      {
        name: 'PrimaryOnCallEmail'
        emailAddress: oncallEmail
        useCommonAlertSchema: true
      }
    ], empty(secondaryOncallEmail) ? [] : [
      {
        name: 'SecondaryOnCallEmail'
        emailAddress: secondaryOncallEmail
        useCommonAlertSchema: true
      }
    ])
    smsReceivers: [
      {
        name: 'PrimaryOnCallSms'
        countryCode: oncallSmsCountryCode
        phoneNumber: oncallSmsPhoneNumber
      }
    ]
    webhookReceivers: empty(pagingWebhookUri) ? [] : [
      {
        name: 'PagingSystemWebhook'
        serviceUri: pagingWebhookUri
        useCommonAlertSchema: true
        useAadAuth: false
      }
    ]
  }
}

resource aksCpuMetricAlert 'Insights/metricAlerts@2018-03-01' = {
  name: cpuAlertName
  location: 'global'
  tags: tags
  properties: {
    description: 'Alerts when AKS cluster node CPU usage exceeds ${cpuThresholdPercent}% averaged over ${alertWindowSize}.'
    severity: alertSeverity
    enabled: true
    scopes: [
      aksClusterResourceId
    ]
    evaluationFrequency: alertEvaluationFrequency
    windowSize: alertWindowSize
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    targetResourceRegion: location
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'NodeCpuUsagePercentage'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          metricName: 'node_cp