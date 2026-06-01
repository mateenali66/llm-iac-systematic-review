@description('The prefix for all resource names.')
param namePrefix string = 'prod-aks-mon'

@description('The Azure region where all resources should be deployed.')
param location string = resourceGroup().location

@description('The resource ID of the AKS cluster to monitor.')
param aksClusterResourceId string

@description('The email address for the on-call engineer to receive alerts.')
param onCallEmailAddress string

@description('The CPU percentage threshold for triggering the alert (e.g., 80 for 80%).')
@minValue(1)
@maxValue(100)
param cpuThreshold int = 80

@description('The severity of the alert. 0=critical, 1=error, 2=warning, 3=informational, 4=verbose.')
@allowed([
  0
  1
  2
  3
  4
])
param alertSeverity int = 1

@description('The period of time (in ISO 8601 duration format) that is used to monitor alert activity.')
param alertWindowSize string = 'PT15M'

@description('The frequency (in ISO 8601 duration format) for this alert rule.')
param alertEvaluationFrequency string = 'PT5M'

@description('Tags to apply to all resources.')
param tags object = {
  environment: 'Production'
  managedBy: 'Bicep'
}

var logAnalyticsWorkspaceName = '${namePrefix}-logs-${uniqueString(resourceGroup().id)}'
var actionGroupName = '${namePrefix}-ag-oncall'
var metricAlertName = '${namePrefix}-alert-akscpu'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: namePrefix
    enabled: true
    emailReceivers: [
      {
        name: 'OnCallEmail'
        emailAddress: onCallEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

resource metricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: metricAlertName
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when AKS cluster average node CPU usage exceeds ${cpuThreshold}% over ${alertWindowSize}.'
    severity: alertSeverity
    enabled: true
    scopes: [
      aksClusterResourceId
    ]
    evaluationFrequency: alertEvaluationFrequency
    windowSize: alertWindowSize
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'