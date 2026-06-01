@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name used in resource naming')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'prod'

@description('Workload name used in resource naming')
@minLength(2)
@maxLength(10)
param workloadName string = 'app'

@description('Address space for the virtual network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the web subnet')
param webSubnetPrefix string = '10.0.1.0/24'

@description('Address prefix for the app subnet')
param appSubnetPrefix string = '10.0.2.0/24'

@description('Address prefix for the data subnet')
param dataSubnetPrefix string = '10.0.3.0/24'

@description('Address prefix for the Azure Bastion subnet (must be /26 or larger)')
param bastionSubnetPrefix string = '10.0.255.0/26'

@description('SKU for Azure Bastion')
@allowed([
  'Basic'
  'Standard'
])
param bastionSku string = 'Standard'

@description('Tags applied to all resources')
param tags object = {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
}

var namePrefix = '${workloadName}-${environment}'
var vnetName = 'vnet-${namePrefix}'
var bastionName = 'bas-${namePrefix}'
var bastionPipName = 'pip-bas-${namePrefix}'
var nsgWebName = 'nsg-web-${namePrefix}'
var nsgAppName = 'nsg-app-${namePrefix}'
var nsgDataName = 'nsg-data-${namePrefix}'
var bastionNsgName = 'nsg-bastion-${namePrefix}'

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgWebName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          description: 'Allow HTTPS from the Internet to the web tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: webSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          description: 'Allow HTTP from the Internet to the web tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: webSubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Bastion-Inbound'
        properties: {
          description: 'Allow SSH/RDP from Bastion subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: webSubnetPrefix
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-AppTier-Inbound'
        properties: {
          description: 'Deny direct traffic from app tier to web tier'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: webSubnetPrefix
          access: 'Deny'
          priority: 200
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-DataTier-Inbound'
        properties: {
          description: 'Deny direct traffic from data tier to web tier'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: dataSubnetPrefix
          destinationAddressPrefix: webSubnetPrefix
          access: 'Deny'
          priority: 210
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Web-To-App-Outbound'
        properties: {
          description: 'Allow web tier to communicate with app tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: appSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Deny-Web-To-Data-Outbound'
        properties: {
          description: 'Web tier must not reach data tier directly'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
          access: 'Deny'
          priority: 200
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgAppName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Web-To-App-Inbound'
        properties: {
          description: 'Allow HTTPS from web tier'
          protocol: 'Tc