@description('The base name for all resources. A unique string will be appended to this name.')
param appName string

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The retention period in days for the Log Analytics Workspace. Must be between 30 and 730.')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionInDays int = 90

@description('The percentage of telemetry data to sample. Value from 0.0 to 100.0.')
@minValue(0)
@maxValue(100)
param appInsightsSamplingPercentage float = 100.0

var logAnalyticsWorkspaceName = '${appName}-log'
var appInsightsName = '${appName}-ai'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logAnalyticsRetentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    SamplingPercentage: appInsightsSamplingPercentage
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output appInsightsId string = appInsights.id