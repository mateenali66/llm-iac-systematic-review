@description('The Azure region where resources will be deployed.')
param location string = resourceGroup().location

@description('The environment name (e.g., dev, test, prod).')
@allowed([
  'dev'
  'test'
  'staging'
  'prod'
])
param environment string = 'prod'

@description('The base name used for all resources. Must be globally unique-friendly.')
@minLength(3)
@maxLength(20)
param workloadName string

@description('Retention period in days for Log Analytics workspace data.')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionDays int = 90

@description('The pricing tier (SKU) for the Log Analytics workspace.')
@allowed([
  'PerGB2018'
  'CapacityReservation'
  'Free'
  'Standalone'
  'PerNode'
  'Premium'
])
param logAnalyticsSku string = 'PerGB2018'

@description('Daily ingestion cap in GB for Log Analytics. Use -1 for no cap.')
param dailyQuotaGb int = -1

@description('The kind of Application Insights resource.')
@allowed([
  'web'
  'other'
])
param appInsightsKind string = 'web'

@description('Application type for Application Insights.')
@allowed([
  'web'
  'other'
])
param appInsightsApplicationType string = 'web'

@description('Disable public network access for ingestion in Application Insights.')
param disablePublicNetworkAccessForIngestion bool = false

@description('Disable public network access for querying in Application Insights.')
param disablePublicNetworkAccessForQuery bool = false

@description('Tags to apply to all resources.')
param tags object = {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
}

var logAnalyticsWorkspaceName = 'log-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
var appInsightsName = 'appi-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: logAnalyticsRetentionDays
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

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: appInsightsKind
  tags: tags
  properties: {
    Application_Type: appInsightsApplicationType
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: disablePublicNetworkAccessForIngestion ? 'Disabled' : 'Enabled'
    publicNetworkAccessForQuery: disablePublicNetworkAccessForQuery ? 'Disabled' : 'Enabled'
    DisableIpMasking: false
    DisableLocalAuth: false
    SamplingPercentage: 100
  }
}

resource appInsightsDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${appInsightsName}'
  scope: appInsights
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AppAvailabilityResults'
        enabled: true
      }
      {
        category: 'AppBrowserTimings'
        enabled: true
      }
      {
        category: 'AppEvents'
        enabled: true
      }
      {
        category: 'AppMetrics'
        enabled: true
      }
      {
        category: 'AppDependencies'
        enabled: true
      }
      {
        category: 'AppExceptions'
        enabled: true
      }
      {
        category: 'AppPageViews'
        enabled: true
      }
      {
        category: 'AppPerformanceCounters'
        enabled: true
      }
      {
        category: 'AppRequests'
        enabled: true
      }
      {
        category: 'AppSystemEvents'
        enabled: true
      }
      {
        category: 'AppTraces'
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

@description('The resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace.')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('The customer ID (workspace ID) of the Log Analytics workspace.')
output logAnalyticsWorkspaceCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('The resource ID of the Application Insights instance.')
output appInsightsId string = appInsights.id

@description('The name of the Application Insights instance.')
output appInsightsName string = appInsights.name

@description('The Application Insights connection string. Use this with the App Service.')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('The Application Insights instrumentation key (legacy, prefer connection string).')
output appInsightsIn