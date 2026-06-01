param location string = resourceGroup().location
param vnetName string = 'vnet-main'
param addressPrefix string = '10.0.0.0/16'
param webSubnetPrefix string = '10.0.1.0/24'
param appSubnetPrefix string = '10.0.2.0/24'
param dataSubnetPrefix string = '10.0.3.0/24'
param bastionSubnetPrefix string = '10.0.10.0/27'
param nsgName string = 'nsg-tiers'
param bastionName string = 'bastionHost'
param tags object = {
  environment: 'prod'
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-To-Web'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: webSubnetPrefix
          destinationPortRange: '80'
        }
      }
      {
        name: 'Allow-HTTPS-To-Web'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: webSubnetPrefix
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-App-From-Web-443'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: webSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: appSubnetPrefix
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-Data-From-App-1433'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: appSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetPrefix
          destinationPortRange: '1433'
        }
      }
      {
        name: 'Allow-Bastion-To-Web-Admin'
        properties: {
          priority: 140
          direction: 'Inbound'
          access: 'Allow'
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
        name: 'Allow-Bastion-To-App-Admin'
        properties: {
          priority: 150
          direction: 'Inbound'
          access: 'Allow'
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
        name: 'Allow-Bastion-To-Data-Admin'
        properties: {
          priority: 160
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: bastionSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetPrefix
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
      {
        name: 'Allow-Intra-Web'
        properties: {
          priority: 170
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: webSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: webSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'Allow-Intra-App'
        properties: {
          priority: 180
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: appSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: appSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'Allow-Intra-Data'
        properties: {
          priority: 190
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: dataSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-VNet-To-Web'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: webSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-VNet-To-App'
        properties: {
          priority: 210
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: appSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-VNet-To-Data'
        properties: {
          priority: 220
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetPrefix
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'web'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'app'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'data'
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
  name: '${bastionName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConf'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}