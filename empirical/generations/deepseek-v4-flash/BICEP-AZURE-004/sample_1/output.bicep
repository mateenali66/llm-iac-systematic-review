param location = resourceGroup().location
param vnetName = 'vnet-main'
param vnetAddressPrefix = '10.0.0.0/16'
param webSubnetPrefix = '10.0.1.0/24'
param appSubnetPrefix = '10.0.2.0/24'
param dataSubnetPrefix = '10.0.3.0/24'
param bastionSubnetPrefix = '10.0.4.0/24'
param bastionName = 'bastion-host'
param bastionPublicIpName = 'bastion-public-ip'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
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

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-tier-restriction'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowWebToApp'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: appSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAppToData'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllOtherInterTier'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: bastionPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ip-config'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}