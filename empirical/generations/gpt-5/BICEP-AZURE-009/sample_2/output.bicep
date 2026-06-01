@description('Location for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Name of the Log Analytics workspace.')
param workspaceName string

@description('Name of the Application Insights instance.')
param appInsightsName string

@description('Retention period in days for Log Analytics workspace.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('SKU for the Log Analytics workspace.')
@allowed([
  'PerGB2018'
])
param workspaceSku string = 'PerGB2018'

@description('Resource tags to apply to all resources.')
param tags object = {}

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  sku: {
    name: workspaceSku
  }
  properties: {
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
    IngestionMode: 'LogAnalytics'
    DisableIpMasking: false
  }
}

output logAnalyticsWorkspaceId string = law.id
output logAnalyticsWorkspaceCustomerId string = law.properties.customerId
output applicationInsightsResourceId string = appInsights.id
output applicationInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString