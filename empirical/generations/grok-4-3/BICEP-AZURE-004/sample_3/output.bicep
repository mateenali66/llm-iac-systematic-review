@description('The Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the Virtual Network.')
param vnetName string = 'vnet-hub'

@description('Address prefix for the Virtual Network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the web subnet.')
param webSubnetPrefix string = '10.0.1.0/24'

@description('Address prefix for the app subnet.')
param appSubnetPrefix string = '10.0.2.0/24'

@description('Address prefix for the data subnet.')
param dataSubnetPrefix string = '10.0.3.0/24'

@description('Address prefix for the Azure Bastion subnet.')
param bastionSubnetPrefix string = '10.0.0.0/26'

@description('Name of the Network Security Group.')
param nsgName string = 'nsg-tiered'

@description('Name of the Azure Bastion host.')
param bastionName string = 'bas-hub'

@description('Name of the public IP for Bastion.')
param bastionPipName string = 'pip-bastion'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Web-to-App-HTTPS'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: appSubnetPrefix
        }
      }
      {
        name: 'Allow-App-to-Data-SQL'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
        }
      }
      {
        name: 'Deny-Web-to-Data'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: dataSubnetPrefix
        }
      }
      {
        name: 'Deny-All-Inbound-Internet'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
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
      addressPrefixes: [
        vnetAddressPrefix
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

resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: bastionPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}