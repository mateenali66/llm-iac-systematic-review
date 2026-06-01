param location string = resourceGroup().location
param functionAppName string
param storageAccountName string
param keyVaultName string
param appServicePlanName string = '${functionAppName}-consumption'
param logAnalyticsWorkspaceName string = '${functionAppName}-law'
param applicationInsightsName string = '${functionAppName}-ai'
@allowed([
  'dotnet-isolated'
  'dotnet'
  'node'
  'python'
  'java'
  'powershell'
])
param functionsWorkerRuntime string = 'dotnet-isolated'
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  sku: {
    name: 'PerGB2018'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    IngestionMode: 'LogAnalytics'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
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
    networkRuleSet: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, ''2023-01-01'').keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enabledForTemplateDeployment: false
    enabledForDeployment: false
    enabledForDiskEncryption: false
    publicNetworkAccess: 'Enabled'
    softDeleteRetentionInDays: 90
    sku: {
      family: 'A'
      name: 'standard'
    }
  }
}

resource storageConnSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVault.name}/AzureWebJobsStorage'
  properties: {
    value: storageConnectionString
    contentType: 'text/plain'
  }
  dependsOn: [
    keyVault
    storage
  ]
}

resource plan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      linuxFxVersion: ''
      minimumTlsVersion: '1.2'
      http20Enabled: true
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionsWorkerRuntime
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: '@Microsoft.KeyVault(SecretUri=${reference(resourceId(''Microsoft.KeyVault/vaults/secrets'', keyVault.name, ''AzureWebJobsStorage''), ''2023-07-01'').secretUriWithVersion})'
        }
      ]
    }
  }
  dependsOn: [
    storageConnSecret
  ]
}

resource kvSecretsUserRA 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, '4633458b-17de-408a-b874-0445c86b69e6', functionApp.name)
  scope: keyVault
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'ServicePrincipal'
  }
}

output functionAppId string = functionApp.id
output functionAppDefaultHostname string = functionApp.properties.defaultHostName
output appInsightsConnectionString string = appInsights.properties.ConnectionString