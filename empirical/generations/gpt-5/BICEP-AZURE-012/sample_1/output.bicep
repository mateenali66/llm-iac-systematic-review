param namePrefix string = 'srvless'
param location string = resourceGroup().location
param osType string = 'linux' {
  allowed: [
    'linux'
    'windows'
  ]
}
param runtime string = 'dotnet-isolated' {
  allowed: [
    'dotnet'
    'dotnet-isolated'
    'node'
    'python'
    'powershell'
    'java'
  ]
}
param corsAllowedOrigins array = []
param appSettings object = {}
param tags object = {}
param aiRetentionInDays int = 30
param storageSkuName string = 'Standard_LRS'
param minTlsVersion string = '1.2' {
  allowed: [
    '1.0'
    '1.1'
    '1.2'
  ]
}

var uniq = uniqueString(resourceGroup().id, namePrefix)
var uniqShort = substring(uniq, 0, 6)
var storageAccountName = toLower('st${uniq}fa')
var lawName = toLower('law-${uniq}')
var appInsightsName = toLower('appi-${uniq}')
var planName = toLower('plan-${namePrefix}-${uniqShort}')
var functionAppName = toLower('${namePrefix}-func-${uniqShort}')
var contentShareName = toLower('func${uniqShort}content')
var functionKind = osType == 'linux' ? 'functionapp,linux' : 'functionapp'

resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  properties: {
    retentionInDays: aiRetentionInDays
    features: {
      searchVersion: 1
    }
  }
  sku: {
    name: 'PerGB2018'
  }
  tags: tags
}

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: la.id
    IngestionMode: 'LogAnalytics'
  }
  tags: tags
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
  tags: tags
}

resource storageAtp 'Microsoft.Security/advancedThreatProtectionSettings@2022-01-01-preview' = {
  name: 'current'
  scope: storage
  properties: {
    isEnabled: true
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: osType == 'linux'
  }
  tags: tags
}

resource func 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  kind: functionKind
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      appSettings: concat(
        [
          {
            name: 'AzureWebJobsStorage'
            value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, ''2023-01-01'').keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
          }
          {
            name: 'FUNCTIONS_EXTENSION_VERSION'
            value: '~4'
          }
          {
            name: 'FUNCTIONS_WORKER_RUNTIME'
            value: runtime
          }
          {
            name: 'WEBSITE_RUN_FROM_PACKAGE'
            value: '1'
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: appi.properties.ConnectionString
          }
        ],
        osType == 'windows' ? [
          {
            name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
            value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, ''2023-01-01'').keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
          }
          {
            name: 'WEBSITE_CONTENTSHARE'
            value: contentShareName
          }
        ] : [],
        [for k in keys(appSettings): {
          name: k
          value: string(appSettings[k])
        }]
      )
      minTlsVersion: minTlsVersion
      ftpsState: 'Disabled'
      http20Enabled: true
      cors: {
        allowedOrigins: corsAllowedOrigins
        supportCredentials: false
      }
    }
  }
  tags: tags
}

resource funcDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${functionAppName}'
  scope: func
  properties: {
    workspaceId: la.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
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
        category: 'AppServiceIPSecAuditLogs'
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

output functionAppName string = func.name
output functionDefaultHostname string = func.properties.defaultHostName
output functionPrincipalId string = func.identity.principalId
output storageAccountName string = storage.name
output appInsightsConnectionString string = appi.properties.ConnectionString