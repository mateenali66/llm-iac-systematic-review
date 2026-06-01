@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the Log Analytics workspace.')
param logAnalyticsWorkspaceName string

@description('Name of the Application Insights instance.')
param applicationInsightsName string

@description('SKU for the Log Analytics workspace.')
param logAnalyticsSku string = 'PerGB2018'

@description('Data retention in days for the Log Analytics workspace.')
param retentionInDays int = 30

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: retentionInDays
    features: {
      searchVersion: 1
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    Flow_Type: 'Bluefield'
    Request_Source: 'IbizaAIExtension'
  }
}