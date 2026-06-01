param location string = resourceGroup().location
param vnetName string = 'myVnet'
param webSubnetPrefix string = '10.0.1.0/24'
param appSubnetPrefix string = '10.0.2.0/24'
param dataSubnetPrefix string = '10.0.3.0/24'
param nsgName string = 'myNsg'
param bastionName string = 'myBastion'

var vnetAddressPrefix = '10.0.0.0/16'

resource vnetResource 'Microsoft.Network/virtualNetworks@2022-01-01' = {
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
    ]
  }
}

resource nsgResource 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-web-to-app'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '10.0.2.0/24'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-app-to-data'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: '10.0.2.0/24'
          destinationAddressPrefix: '10.0.3.0/24'
          access: 'Allow'
          priority: 102
          direction: 'Inbound'
        }
      }
      {
        name: 'deny-all'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 103
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource webSubnetNsg 'Microsoft.Network/subnets@2022-01-01' = {
  name: '${vnetName}/web'
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
  }
}

resource appSubnetNsg 'Microsoft.Network/subnets@2022-01-01' = {
  name: '${vnetName}/app'
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
  }
}

resource dataSubnetNsg 'Microsoft.Network/subnets@2022-01-01' = {
  name: '${vnetName}/data'
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
  }
}

resource bastionResource 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfiguration'
        properties: {
          subnet: {
            id: webSubnetNsg.id
          }
          publicIpAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', 'bastionPublicIp')
          }
        }
      }
    ]
  }
  dependsOn: [
    webSubnetNsg
  ]
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'bastionPublicIp'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
  }
}