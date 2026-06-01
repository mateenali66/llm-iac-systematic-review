@description('Specifies the prefix for the storage account name. Must be 3-11 characters, lowercase letters or numbers.')
@minLength(3)
@maxLength(11)
param namePrefix string

@description('Specifies the location for the resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Specifies the SKU for the storage account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
])
param skuName string = 'Standard_LRS'

@description('Specifies the tags to apply to the resources.')
param tags object = {}

var storageAccountName = toLower('${namePrefix}${uniqueString(resourceGroup().id)}')

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }