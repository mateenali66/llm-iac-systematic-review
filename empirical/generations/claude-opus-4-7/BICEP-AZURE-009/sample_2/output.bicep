@description('The Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name used for tagging and resource naming (e.g., dev, test, prod).')
@allowed([
  'dev'
  'test'
  'staging'
  'prod'
])
param environment string = 'prod'

@description('Workload or application name used as a prefix for resource naming.')
@minLength(2)
@maxLength(20)
param workloadName string

@description('Retention period in days for the Log Analytics workspace.')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionInDays int = 90

@description('Daily ingestion cap in GB for the Log Analytics workspace. Set to -1 for no cap.')
param logAnalyticsDailyQuotaGb int = -1

@description('SKU for the Log Analytics workspace.')
@allowed([
  'PerGB2018'
  'CapacityReservation'
  'Free'
  'Standalone'
  'PerNode'
])
param logAnalyticsSku string = 'PerGB2018'

@description('Application type for Application Insights.')
@allowed([
  'web'
  'other'
])
param applicationInsightsType string = 'web'

@description('Disable non-AAD based authentication for ingestion.')
param disableLocalAuth bool = false

@description('Tags applied to all resources.')
param tags object = {
  environment: environment
  workload: workloadName
  managedBy: 'Bicep'
}

var resourceSuffix = '${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = 'log-${resourceSuffix}'
var applicationInsightsName = 'appi-${resourceSuffix}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: logAnalyticsRetentionInDays
    workspaceCapping: {
      dailyQuotaGb: logAnalyticsDailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: disableLocalAuth
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: applicationInsightsType
  properties: {
    Application_Type: applicationInsightsType
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    DisableLocalAuth: disableLocalAuth
    RetentionInDays: logAnalyticsRetentionInDays
  }
}

@description('The resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace.')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('The customer ID (workspace ID) of the Log Analytics workspace.')
output logAnalyticsCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('The resource ID of the Application Insights instance.')
output applicationInsightsId string = applicationInsights.id

@description('The name of the Application Insights instance.')
output applicationInsightsName string = applicationInsights.name

@description('The Application Insights connection string. Use this in App Service configuration.')
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString

@description('The Application Insights instrumentation key (legacy; prefer connection string).')
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey