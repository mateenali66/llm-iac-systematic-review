@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name used for resource naming and tagging')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'prod'

@description('Workload/application name used for resource naming')
@minLength(2)
@maxLength(10)
param workloadName string = 'app'

@description('Address space for the Virtual Network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the web tier subnet')
param webSubnetPrefix string = '10.0.1.0/24'

@description('Address prefix for the app tier subnet')
param appSubnetPrefix string = '10.0.2.0/24'

@description('Address prefix for the data tier subnet')
param dataSubnetPrefix string = '10.0.3.0/24'

@description('Address prefix for the Azure Bastion subnet (must be /26 or larger)')
param bastionSubnetPrefix string = '10.0.255.0/26'

@description('SKU for Azure Bastion')
@allowed([
  'Basic'
  'Standard'
])
param bastionSku string = 'Standard'

@description('Resource tags')
param tags object = {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
}

var namePrefix = '${workloadName}-${environment}'
var vnetName = 'vnet-${namePrefix}'
var bastionName = 'bas-${namePrefix}'
var bastionPipName = 'pip-${bastionName}'

var nsgWebName = 'nsg-${namePrefix}-web'
var nsgAppName = 'nsg-${namePrefix}-app'
var nsgDataName = 'nsg-${namePrefix}-data'

// ---------- NSG: Web Tier ----------
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgWebName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: webSubnetPrefix
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: webSubnetPrefix
          destinationPortRange: '80'
        }
      }
      {
        name: 'Allow-Bastion-Inbound'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: bastionSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: webSubnetPrefix
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
      {
        name: 'Deny-AppTier-Inbound'
        properties: {
          priority: 300
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: appSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: webSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-DataTier-Inbound'
        properties: {
          priority: 310
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: dataSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: webSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Allow-AppTier-Outbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Outbound'
          protocol: 'Tcp'
          sourceAddressPrefix: webSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: appSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-DataTier-Outbound'
        properties: {
          priority: 200
          access: 'Deny'
          direction: 'Outbound'
          protocol: '*'
          sourceAddressPrefix: webSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetPrefix
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ---------- NSG: App Tier ----------
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgAppName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-WebTier-Inbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: web