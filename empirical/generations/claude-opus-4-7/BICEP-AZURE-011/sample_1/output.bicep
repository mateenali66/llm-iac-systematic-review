@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name used for tagging and resource naming')
param environment string = 'prod'

@description('Workload name used as prefix for resource names')
@minLength(3)
@maxLength(10)
param workloadName string = 'appgw'

@description('Admin username for the backend VMs')
param adminUsername string

@description('SSH public key for the backend VMs')
@secure()
param adminSshPublicKey string

@description('VM size for the backend VMs')
param vmSize string = 'Standard_D2s_v5'

@description('Address space for the virtual network')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('Subnet prefix for the Application Gateway')
param appGwSubnetPrefix string = '10.20.1.0/24'

@description('Subnet prefix for the backend VMs')
param backendSubnetPrefix string = '10.20.2.0/24'

@description('WAF mode')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

var tags = {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
}

var uniqueSuffix = uniqueString(resourceGroup().id, workloadName)
var vnetName = '${workloadName}-vnet-${environment}'
var appGwSubnetName = 'appgw-subnet'
var backendSubnetName = 'backend-subnet'
var appGwName = '${workloadName}-agw-${environment}'
var wafPolicyName = '${workloadName}-waf-${environment}'
var publicIpName = '${workloadName}-pip-${environment}'
var backendNsgName = '${workloadName}-backend-nsg-${environment}'
var appGwNsgName = '${workloadName}-agw-nsg-${environment}'
var logAnalyticsName = '${workloadName}-law-${environment}-${uniqueSuffix}'

var vmCount = 2
var vmNames = [for i in range(0, vmCount): '${workloadName}-vm${i + 1}-${environment}']

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appGwNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: appGwNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-GatewayManager-Inbound'
        properties: {
          priority: 120
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer-Inbound'
        properties: {
          priority: 130
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource backendNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: backendNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-From-AppGw'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: appGwSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
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

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: appGwSubnetName
        properties: {
          addressPrefix: appGwSubnetPrefix
          networkSecurityGroup: {
            id: appGwNsg.id
          }
        }
      }
      {
        name: backendSubnetName
        properties: {