param location string = resourceGroup().location
param vnetName string = 'vnet-prod'
param vnetAddressPrefix string = '10.0.0.0/16'
param webSubnetPrefix string = '10.0.1.0/24'
param appSubnetPrefix string = '10.0.2.0/24'
param dataSubnetPrefix string = '10.0.3.0/24'
param bastionSubnetPrefix string = '10.0.0.0/26'
param bastionName string = 'bas-prod'
param nsgName string = 'nsg-prod-tiers'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Web-To-App'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: appSubnetPrefix
        }
      }
      {
        name: 'Allow-App-To-Data'
        properties: {
          priority: 210
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
        }
      }
      {
        name: 'Allow-Bastion-RDP-SSH'
        properties: {
          priority: 220
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [ '22', '3389' ]
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Deny-All-Inter-Tier'
        properties: {
          priority: 4000
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: vnetAddressPrefix
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ vnetAddressPrefix ]
    }
    subnets: [
      {
        name: 'web'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: { id: nsg.id }
        }
      }
      {
        name: 'app'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: { id: nsg.id }
        }
      }
      {
        name: 'data'
        properties: {
          addressPrefix: dataSubnetPrefix
          networkSecurityGroup: { id: nsg.id }
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

resource pip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${bastionName}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: bastionName
  location: location
  sku: { name: 'Standard' }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: { id: '${vnet.id}/subnets/AzureBastionSubnet' }
          publicIPAddress: { id: pip.id }
        }
      }
    ]
  }
  dependsOn: [ vnet ]
}