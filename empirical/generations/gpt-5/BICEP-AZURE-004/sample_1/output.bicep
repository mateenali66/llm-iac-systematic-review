param location string = resourceGroup().location
param tags object = {}

param vnetName string = 'prod-vnet'
param addressPrefix string = '10.0.0.0/16'

param webSubnetName string = 'web'
param appSubnetName string = 'app'
param dataSubnetName string = 'data'
var bastionSubnetName = 'AzureBastionSubnet'

param webSubnetPrefix string = '10.0.1.0/24'
param appSubnetPrefix string = '10.0.2.0/24'
param dataSubnetPrefix string = '10.0.3.0/24'
param bastionSubnetPrefix string = '10.0.10.0/26'

param bastionName string = 'bastionHost'
param bastionPublicIpName string = 'bastion-pip'

@minValue(1)
@maxValue(65535)
param webToAppPort int = 443

@minValue(1)
@maxValue(65535)
param appToDataPort int = 1433

resource webNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${vnetName}-${webSubnetName}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-http-from-internet'
        properties: {
          priority: 100
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
        name: 'allow-https-from-internet'
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
        name: 'allow-bastion-ssh'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-bastion-rdp'
        properties: {
          priority: 121
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-intra-web'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'deny-other-vnet-to-web'
        properties: {
          priority: 400
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${vnetName}-${appSubnetName}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-bastion-ssh'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-bastion-rdp'
        properties: {
          priority: 101
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-web-to-app'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: string(webToAppPort)
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-intra-app'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'deny-other-vnet-to-app'
        properties: {
          priority: 400
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${vnetName}-${dataSubnetName}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-bastion-ssh'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-bastion-rdp'
        properties: {
          priority: 101
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-app-to-data'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: string(appToDataPort)
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-intra-data'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: dataSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'deny-other-vnet-to-data'
        properties: {
          priority: 400
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
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
        name: webSubnetName
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: webNsg.id
          }
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: appNsg.id
          }
        }
      }
      {
        name: dataSubnetName
        properties: {
          addressPrefix: dataSubnetPrefix
          networkSecurityGroup: {
            id: dataNsg.id
          }
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: bastionPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 30
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ip-config'
        properties: {
          publicIPAddress: {
            id: bastionPip.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, bastionSubnetName)
          }
        }
      }
    ]
  }
}