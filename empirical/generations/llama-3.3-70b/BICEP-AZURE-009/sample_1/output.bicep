param location string = resourceGroup().location
param workspaceName string = 'log-analytics-workspace'
param applicationInsightsName string = 'application-insights-instance'
param appServiceName string = 'app-service-web-application'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceId: logAnalyticsWorkspace.id
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

resource appService 'Microsoft.Web/sites@2021-03-01' = {
  name: appServiceName
  location: location
  properties: {
    serverFarmId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/serverfarms/DefaultServerFarm'
    siteConfig: {
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/azure-app-service/samples/node:12-lts'
    }
  }
  dependsOn: [
    applicationInsights
  ]
  resources: [
    {
      type: 'Microsoft.Web/sites/config'
      name: '${appServiceName}/appsettings'
      properties: {
        ApplicationInsights_InstrumentationKey: applicationInsights.properties.InstrumentationKey
      }
      dependsOn: [
        appService
      ]
    }
  ]
}