param location string = resourceGroup().location
param appInsightsName string = 'appinsights-${uniqueString(resourceGroup().id)}'
param logAnalyticsWorkspaceName string = 'law-${uniqueString(resourceGroup().id)}'
param applicationType string = 'web'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString