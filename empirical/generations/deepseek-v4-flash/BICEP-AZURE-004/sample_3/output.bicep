param location = resourceGroup().location
param vnetName = 'vnet-prod-001'
param vnetAddressPrefix = '10.0.0.0/16'
param webSubnetName = 'snet-web-001'
param webSubnetPrefix = '10.0.1.0/24'
param appSubnetName = 'snet-app-001'
param appSubnetPrefix = '10.0.2.0/24'
param dataSubnetName = 'snet-data-001'
param dataSubnetPrefix = '10.0.3.0/24'
param bastionSubnetName = 'AzureBastionSubnet'
param bastionSubnetPrefix = '10.0.4.0/27'
param nsgName = 'nsg-tier-001'
param bastionHostName = 'bastion-prod-001'
param bastionPublicIpName = 'pip-bastion-001'

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
        name: webSubnetName
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: dataSubnetName
        properties: {
          addressPrefix: dataSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
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

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPFromWebToApp'
        properties: {
          description: 'Allow HTTP from web to app tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: appSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTPSFromWebToApp'
        properties: {
          description: 'Allow HTTPS from web to app tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: appSubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSQLFromAppToData'
        properties: {
          description: 'Allow SQL from app to data tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllOtherInterVNet'
        properties: {
          description: 'Deny all other inter-VNet traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Deny'
          priority: 4096
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

resource bastionHost 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: bastionHostName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName)
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}