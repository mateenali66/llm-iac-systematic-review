param location string = resourceGroup().location
param vnetName string = 'vnet-main'
param vnetAddressPrefixes array = [
  '10.0.0.0/16'
]
param webSubnetPrefix string = '10.0.1.0/24'
param appSubnetPrefix string = '10.0.2.0/24'
param dataSubnetPrefix string = '10.0.3.0/24'
param bastionSubnetPrefix string = '10.0.10.0/27'

param nsgName string = 'nsg-tiers'
param bastionName string = 'bastion-host'
param bastionPipName string = 'pip-bastion'
param tags object = {}

param appPort int = 443
param dbPort int = 1433

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: union(tags, { managedBy: 'bicep' })
  properties: {
    securityRules: [
      {
        name: 'Allow-Internet-Web-HTTP-HTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: webSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Web-To-App'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            string(appPort)
          ]
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: appSubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-App-To-Data'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            string(dbPort)
          ]
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer-To-Web'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: webSubnetPrefix
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Bastion-To-Web-Management'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: webSubnetPrefix
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Bastion-To-App-Management'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: appSubnetPrefix
          access: 'Allow'
          priority: 141
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Bastion-To-Data-Management'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
          access: 'Allow'
          priority: 142
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-Inter-Subnet-Traffic'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Deny'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: union(tags, { managedBy: 'bicep' })
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
    subnets: [
      {
        name: 'web-subnet'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'app-subnet'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'data-subnet'
        properties: {
          addressPrefix: dataSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: bastionPipName
  location: location
  sku: {
    name: 'Standard'
  }
  tags: union(tags, { managedBy: 'bicep' })
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 15
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Standard'
  }
  tags: union(tags, { managedBy: 'bicep' })
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ipcfg'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
    scaleUnits: 2
  }
}