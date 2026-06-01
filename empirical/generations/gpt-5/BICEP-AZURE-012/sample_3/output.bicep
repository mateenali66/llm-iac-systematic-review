param namePrefix string = 'srvless'
param location string = resourceGroup().location
param environment string = 'prod' {
  allowed: [
    'dev'
    'test'
    'staging'
    'prod'
  ]
}
param functionAppName string = '${namePrefix}-func-${uniqueString(resourceGroup().id)}'
param storageAccountName string = toLower(substring(replace('${namePrefix}${uniqueString(resourceGroup().id)}', '-', ''), 0, 24))
param workerRuntime string = 'dotnet' {
  allowed: [
    'dotnet'
    'node'
    'python'
    'java'
    'powershell'
  ]
}
param functionsExtensionVersion string = '~4'
param corsAllowedOrigins array = []
param allowAzurePortalCors bool = true
param runFromPackageUrl string = ''
param appSettings object = {}
param logAnalyticsRetentionInDays int = 30
param tags object = {
  environment: environment
}

var portalCorsOrigins = [
  'https://functions.azure.com'
  'https://functions-staging.azure.com'
  'https://functions-next.azure.com'
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: union(tags, {
    workload: 'functionapp'
  })
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
    accessTier: 'Hot'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${namePrefix}-law-${uniqueString(resourceGroup().id)}'
  location: location
  tags: union(tags, {
    workload: 'functionapp'
  })
  properties: {
    retentionInDays: logAnalyticsRetentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
  sku: {
    name: 'PerGB2018'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${namePrefix}-appi-${uniqueString(resourceGroup().id)}'
  location: location
  tags: union(tags, {
    workload: 'functionapp'
  })
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    DisableIpMasking: false
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${namePrefix}-plan-${uniqueString(resourceGroup().id)}'
  location: location
  tags: union(tags, {
    workload: 'functionapp'
  })
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
    perSiteScaling: false
    maximumElasticWorkerCount: 1
  }
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  tags: union(tags, {
    workload: 'functionapp'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      minimumTlsVersion: '1.2'
      http20Enabled: true
      scmMinTlsVersion: '1.2'
      ftpsState: 'Disabled'
      cors: {
        allowedOrigins: concat(allowAzurePortalCors ? portalCorsOrigins : [], corsAllowedOrigins)
        supportCredentials: false
      }
    }
  }
}

var storageKey = listKeys(storageAccount.id, '2023-01-01').keys[0].value
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageKey};EndpointSuffix=${environment().suffixes.storage}'
var runFromPackageSetting = empty(runFromPackageUrl) ? '1' : runFromPackageUrl

resource functionAppSettings 'Microsoft.Web/sites/config@2022-09-01' = {
  name: '${functionApp.name}/appsettings'
  properties: union({
      AzureWebJobsStorage: storageConnectionString
      FUNCTIONS_EXTENSION_VERSION: functionsExtensionVersion
      FUNCTIONS_WORKER_RUNTIME: workerRuntime
      WEBSITE_RUN_FROM_PACKAGE: runFromPackageSetting
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
    }, appSettings)
  dependsOn: [
    functionApp
    storageAccount
    applicationInsights
  ]
}

resource functionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (true) {
  name: 'sendtoLogAnalytics'
  scope: functionApp
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
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

output functionAppName string = functionApp.name
output functionAppEndpoint string = 'https://${functionApp.properties.defaultHostName}'
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output logAnalyticsWorkspaceId string = logAnalytics.id