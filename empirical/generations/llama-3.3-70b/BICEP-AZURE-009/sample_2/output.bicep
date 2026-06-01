param location string = resourceGroup().location
param workspaceName string = 'logAnalyticsWorkspace'
param applicationInsightsName string = 'applicationInsights'
param appServiceName string = 'appServiceWebApp'

resource logAnalyticsWorkspaceResource 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource applicationInsightsResource 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceId: logAnalyticsWorkspaceResource.id
  }
  dependsOn: [
    logAnalyticsWorkspaceResource
  ]
}

resource appServicePlanResource 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: 'appServicePlan'
  location: location
  properties: {
    numberOfWorkers: 1
    reserved: true
    tier: 'Standard'
    family: 'S'
    size: 'S1'
  }
}

resource appServiceWebAppResource 'Microsoft.Web/sites@2021-03-01' = {
  name: appServiceName
  location: location
  properties: {
    serverFarmId: appServicePlanResource.id
    httpsOnly: true
  }
  dependsOn: [
    appServicePlanResource
  ]
  resources: [
    {
      type: 'Microsoft.Web/sites/config'
      name: 'web'
      properties: {
        applicationInsights: {
          InstrumentationKey: applicationInsightsResource.properties.InstrumentationKey
        }
      }
      dependsOn: [
        applicationInsightsResource
      ]
    }
  ]
}