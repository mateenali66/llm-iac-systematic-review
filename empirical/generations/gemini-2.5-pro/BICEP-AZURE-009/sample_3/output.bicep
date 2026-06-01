@description('The base name for the application and related resources.')
@minLength(3)
param appName string

@description('The deployment environment name (e.g., dev, test, prod).')
@allowed([
  'dev'
  'test'
  'staging'
  'prod'
])
param environment string = 'prod'

@description('The Azure region for resource deployment. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The SKU for the Log Analytics workspace.')
@allowed([
  'PerGB2018'
  'Free'
  'Standard'
  'Premium'
])
param logAnalyticsSku string = 'PerGB2018'

@description('Data retention in days for the Log Analytics workspace. Must be between 30 and 730.')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionInDays int = 90

var logAnalyticsWorkspaceName = 'la-${appName}-${environment}'
var appInsightsName = 'appi-${appName}-${environment}'
var commonTags = {
  environment: environment
  application: appName
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: logAnalyticsRetentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: commonTags