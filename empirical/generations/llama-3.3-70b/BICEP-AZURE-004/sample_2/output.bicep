param location string = resourceGroup().location
param vnetName string = 'myVnet'
param webSubnetPrefix string = '10.0.1.0/24'
param appSubnetPrefix string = '10.0.2.0/24'
param dataSubnetPrefix string = '10.0.3.0/24'
param nsgName string = 'myNsg'
param bastionName string = 'myBastion'
param bastionSubnetPrefix string = '10.0.4.0/24'

var vnetAddressPrefix = '10.0.0.0/16'

resource vnetResource 'Microsoft.Network/virtualNetworks@2022-07-01' = {
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
        }
      }
      {
        name: 'app'
        properties: {
          addressPrefix: appSubnetPrefix
        }
      }
      {
        name: 'data'
        properties: {
          addressPrefix: dataSubnetPrefix
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

resource nsgResource 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-https'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-ssh'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'deny-web-to-app'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '10.0.2.0/24'
          access: 'Deny'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'deny-app-to-data'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.0.2.0/24'
          destinationAddressPrefix: '10.0.3.0/24'
          access: 'Deny'
          priority: 130
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource bastionResource 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfiguration'
        properties: {
          subnet: {
            id: vnetResource.properties.subnets[3].id
          }
          publicIpAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', 'bastionPublicIp')
          }
        }
      }
    ]
  }
  dependsOn: [
    vnetResource
  ]
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: 'bastionPublicIp'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource webSubnetNsgAssociation 'Microsoft.Network/subnets@2022-07-01' = {
  name: '${vnetName}/web'
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
  }
}

resource appSubnetNsgAssociation 'Microsoft.Network/subnets@2022-07-01' = {
  name: '${vnetName}/app'
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
  }
}

resource dataSubnetNsgAssociation 'Microsoft.Network/subnets@2022-07-01' = {
  name: '${vnetName}/data'
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
  }
}