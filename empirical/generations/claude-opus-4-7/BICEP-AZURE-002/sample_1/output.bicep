@description('The name of the storage account. Must be globally unique, 3-24 lowercase alphanumeric characters.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('The Azure region for the storage account.')
param location string = resourceGroup().location

@description('The SKU for the storage account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param skuName string = 'Standard_ZRS'

@description('Custom domain to associate with the static assets endpoint (optional).')
param customDomainName string = ''

@description('Index document for static website hosting.')
param indexDocument string = 'index.html'

@description('Error document (404 fallback) for static website hosting.')
param errorDocument string = '404.html'

@description('CORS allowed origins for static assets (e.g., your application domain).')
param corsAllowedOrigins array = [
  '*'
]

@description('Tags to apply to all resources.')
param tags object = {
  environment: 'production'
  workload: 'static-assets'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    customDomain: empty(customDomainName) ? null : {
      name: customDomainName
      useSubDomainName: true
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: corsAllowedOrigins
          allowedMethods: [
            'GET'
            'HEAD'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 3600
        }
      ]
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    isVersioningEnabled: true
    changeFeed: {
      enabled: true
      retentionInDays: 30
    }
  }
}

resource assetsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: '$web'
  properties: {
    publicAccess: 'None'
  }
}

resource staticWebsiteDeploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${storageAccountName}-enable-static-website'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    retentionInterval: 'PT1H'
    timeout: 'PT10M'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'StorageAccountName'
        value: storageAccount.name
      }
      {
        name: 'IndexDocument'
        value: indexDocument
      }
      {
        name: 'ErrorDocument'
        value: errorDocument
      }
    ]
    scriptContent: '''
      $ctx = (Get-AzStorageAccount -ResourceGroupName $env:ResourceGroupName -Name $env:StorageAccountName).Context
      Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument $env:IndexDocument -ErrorDocument404Path $env:ErrorDocument
    '''
  }
  dependsOn: [
    assetsContainer
    roleAssignment
  ]
}

resource deploymentScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${storageAccountName}-script-mi'
  location: location
  tags: tags
}

var storageAccountContributorRoleId = '17d1049b-9a84-46fb-8f53-869881c3d3ab'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, deploymentScriptIdentity.id, storageAccountContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageAccountContributorRoleId