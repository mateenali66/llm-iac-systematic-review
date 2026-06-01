param location string = resourceGroup().location
param appInsightsName string = 'appinsights-${uniqueString(resourceGroup().id)}'
param logAnalyticsWorkspaceName string = 'law-${uniqueString(resourceGroup().id)}'
param appInsightsApplicationType string = 'web'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: appInsightsApplicationType
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    IngestionMode: 'LogAnalytics'
    DisableIpMasking: false
    ImmediatePurgeDataOn30Days: false
    RetentionInDays: 90
    SamplingPercentage: 100
    disableLocalAuth: false
    ForceCustomerStorageForProfiler: false
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString