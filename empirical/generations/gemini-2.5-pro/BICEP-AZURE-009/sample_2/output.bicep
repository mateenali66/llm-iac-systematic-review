@description('The base name for the resources. A unique string will be appended to this name for uniqueness.')
@minLength(3)
param appName string

@description('The Azure region where the resources should be deployed.')
param location string = resourceGroup().location

@description('The SKU for the Log Analytics Workspace.')
@allowed([
  'PerGB2018'
  'Free'
  'Standalone'
  'PerNode'
  'Standard'
  'Premium'
])
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('The data retention in days for the Log Analytics Workspace. 30-730 for most SKUs.')
@minValue(30)
@maxValue(730)
param logRetentionInDays int = 90

var logAnalyticsWorkspaceName = 'log-${appName}-${uniqueString(resourceGroup().id)}'
var appInsightsName = 'appi-${appName}-${uniqueString(resourceGroup().id)}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSku
    }
    retentionInDays: logRetentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output applicationInsightsId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString