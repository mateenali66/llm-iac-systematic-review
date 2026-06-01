@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name used for resource naming')
@minLength(2)
@maxLength(10)
param environmentName string = 'prod'

@description('Admin username for VMs')
param adminUsername string

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('VM size')
param vmSize string = 'Standard_D2s_v5'

@description('VNet address space')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Application Gateway subnet prefix')
param appGwSubnetPrefix string = '10.0.1.0/24'

@description('Backend VMs subnet prefix')
param backendSubnetPrefix string = '10.0.2.0/24'

@description('Number of backend VMs')
param vmCount int = 2

@description('WAF mode')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

var namePrefix = 'agw-${environmentName}-${uniqueString(resourceGroup().id)}'
var vnetName = 'vnet-${environmentName}'
var appGwSubnetName = 'snet-appgw'
var backendSubnetName = 'snet-backend'
var appGwName = 'appgw-${environmentName}'
var appGwPipName = 'pip-${appGwName}'
var nsgAppGwName = 'nsg-appgw-${environmentName}'
var nsgBackendName = 'nsg-backend-${environmentName}'
var wafPolicyName = 'waf-${environmentName}'

resource nsgAppGw 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgAppGwName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-GatewayManager'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgBackend 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgBackendName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-AppGw-HTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: appGwSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
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
            id: nsgAppGw.id
          }
        }
      }
      {
        name: backendSubnetName
        properties: {
          addressPrefix: backendSubnetPrefix
          networkSecurityGroup: {
            id: nsgBackend.id
          }
        }
      }
    ]
  }
}

resource appGwPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: appGwPipName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-09-01' = {
  name: wafPolicyName
  location: location
  properties: {
    policySettings: {
      state: 'Enabled'