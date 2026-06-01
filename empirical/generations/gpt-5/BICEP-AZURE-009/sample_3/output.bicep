param location string = resourceGroup().location
param workspaceName string
@minValue(30)
@maxValue(730)
param workspaceRetentionInDays int = 30
param dailyQuotaGb int = 5
param appInsightsName string
param webAppName string = ''
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: workspaceRetentionInDays
    dailyQuotaGb: dailyQuotaGb
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

resource appInsights 'microsoft.insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: workspace.id
  }
  tags: tags
}

resource webApp 'Microsoft.Web/sites@2023-01-01' existing = if (!empty(webAppName)) {
  name: webAppName
}

resource webAppAppSettings 'Microsoft.Web/sites/config@2023-01-01' = if (!empty(webAppName)) {
  name: '${webApp.name}/appsettings'
  properties: {
    'APPLICATIONINSIGHTS_CONNECTION_STRING': appInsights.properties.ConnectionString
    'APPINSIGHTS_INSTRUMENTATIONKEY': appInsights.properties.InstrumentationKey
    'ApplicationInsightsAgent_EXTENSION_VERSION': '~3'
    'XDT_MicrosoftApplicationInsights_Mode': 'recommended'
  }
}

resource webAppDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(webAppName)) {
  name: 'send-to-loganalytics'
  scope: webApp
  properties: {
    workspaceId: workspace.id
    logs: [
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output logAnalyticsWorkspaceId string = workspace.id
output logAnalyticsWorkspaceName string = workspace.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey