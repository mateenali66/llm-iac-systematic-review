@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name used for resource naming and tagging')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'prod'

@description('Workload or application short name')
@minLength(2)
@maxLength(10)
param workloadName string = 'app'

@description('Address space for the virtual network')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Address prefix for the web tier subnet')
param webSubnetPrefix string = '10.10.1.0/24'

@description('Address prefix for the app tier subnet')
param appSubnetPrefix string = '10.10.2.0/24'

@description('Address prefix for the data tier subnet')
param dataSubnetPrefix string = '10.10.3.0/24'

@description('Address prefix for the AzureBastionSubnet (must be /26 or larger)')
param bastionSubnetPrefix string = '10.10.255.0/26'

@description('Resource tags')
param tags object = {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
}

var namePrefix = '${workloadName}-${environment}'
var vnetName = '${namePrefix}-vnet'
var webNsgName = '${namePrefix}-web-nsg'
var appNsgName = '${namePrefix}-app-nsg'
var dataNsgName = '${namePrefix}-data-nsg'
var bastionNsgName = '${namePrefix}-bastion-nsg'
var bastionPipName = '${namePrefix}-bastion-pip'
var bastionName = '${namePrefix}-bastion'

resource webNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: webNsgName
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
        name: 'Allow-Bastion-SSH-RDP-Inbound'
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
    ]
  }
}

resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: appNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Web-To-App'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: webSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: appSubnetPrefix
          destinationPortRanges: [
            '8080'
            '8443'
          ]
        }
      }
      {
        name: 'Allow-Bastion-SSH-RDP-Inbound'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: bastionSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: appSubnetPrefix
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
      {
        name: 'Deny-DataTier-Inbound'
        properties: {
          priority: 300
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: dataSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPr