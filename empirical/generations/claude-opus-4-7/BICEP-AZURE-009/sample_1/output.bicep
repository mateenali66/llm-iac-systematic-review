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

@description('The base name used to construct resource names.')
@minLength(3)
@maxLength(20)
param workloadName string

@description('The pricing tier (SKU) for the Log Analytics workspace.')
@allowed([
  'Free'
  'Standalone'
  'PerNode'
  'PerGB2018'
  'CapacityReservation'
])
param logAnalyticsSku string = 'PerGB2018'

@description('The retention period in days for Log Analytics data.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('The daily ingestion cap in GB for Log Analytics. Use -1 for no cap.')
param dailyQuotaGb int = -1

@description('The Application Insights resource type. Web is recommended for App Service.')
@allowed([
  'web'
  'other'
])
param applicationType string = 'web'

@description('Resource tags to apply to all resources.')
param tags object = {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
}

var logAnalyticsWorkspaceName = 'log-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = 'appi-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: retentionInDays
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

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    DisableLocalAuth: false
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    RetentionInDays: retentionInDays
  }
}

@description('The resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace.')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('The customer ID (workspace ID) of the Log Analytics workspace.')
output logAnalyticsWorkspaceCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('The resource ID of the Application Insights instance.')
output applicationInsightsId string = applicationInsights.id

@description('The name of the Application Insights instance.')
output applicationInsightsName string = applicationInsights.name

@description('The Application Insights instrumentation key. Prefer the connection string for new applications.')
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey

@description('The Application Insights connection string. Recommended for App Service integration.')
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString