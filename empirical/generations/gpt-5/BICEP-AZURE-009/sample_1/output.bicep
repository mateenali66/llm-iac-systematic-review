param location string = resourceGroup().location
@minLength(3)
param workspaceName string
@minLength(3)
param appInsightsName string
@description('Name of the existing App Service (Microsoft.Web/sites) to configure for monitoring. If empty, no App Service will be configured.')
param webAppName string = ''

@minValue(7)
@maxValue(730)
param retentionInDays int = 30

@description('Enable diagnostic settings on the App Service to send metrics to Log Analytics.')
param enableDiagnosticSettings bool = true

param tags object = {}

resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: la.id
  }
}

resource webApp 'Microsoft.Web/sites@2022-09-01' existing = if (!empty(webAppName)) {
  name: webAppName
}

var currentAppSettings = empty(webAppName) ? {} : list('${webApp.id}/config/appsettings', '2022-09-01')
var aiAppSettings = {
  'APPLICATIONINSIGHTS_CONNECTION_STRING': appInsights.properties.ConnectionString
  'APPINSIGHTS_INSTRUMENTATIONKEY': appInsights.properties.InstrumentationKey
  'ApplicationInsightsAgent_EXTENSION_VERSION': '~3'
}

resource webAppAppSettings 'Microsoft.Web/sites/config@2022-09-01' = if (!empty(webAppName)) {
  name: '${webApp.name}/appsettings'
  properties: empty(currentAppSettings) ? aiAppSettings : union(currentAppSettings.properties, aiAppSettings)
}

resource diagnostic 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnosticSettings && !empty(webAppName)) {
  name: 'send-to-log-analytics'
  scope: webApp
  properties: {
    workspaceId: la.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output logAnalyticsWorkspaceId string = la.id
output applicationInsightsId string = appInsights.id
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString
output applicationInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey