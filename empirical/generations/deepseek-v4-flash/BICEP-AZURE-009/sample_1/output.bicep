param location string = resourceGroup().location
param workspaceName string = 'log-${uniqueString(resourceGroup().id)}'
param appInsightsName string = 'appi-${uniqueString(resourceGroup().id)}'
param applicationType string = 'web'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
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
    DisableIpMasking: false
    Flow_Type: 'Redfield'
    Request_Source: 'IbizaAIExtension'
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString