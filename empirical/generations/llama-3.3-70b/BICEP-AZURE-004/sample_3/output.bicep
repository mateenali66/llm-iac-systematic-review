param location string = resourceGroup().location
param vnetName string = 'myVnet'
param webSubnetPrefix string = '10.0.1.0/24'
param appSubnetPrefix string = '10.0.2.0/24'
param dataSubnetPrefix string = '10.0.3.0/24'
param nsgName string = 'myNsg'
param bastionName string = 'myBastion'

var vnetAddressPrefix = '10.0.0.0/16'

resource vnetResource 'Microsoft.Network/virtualNetworks@2021-08-01' = {
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

resource nsgResource 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '22'
        }
      }
      {
        name: 'allow-web-to-app'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: webSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: appSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'allow-app-to-data'
        properties: {
          priority: 120
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: appSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetPrefix
          destinationPortRange: '*'
        }
      }
      {
        name: 'deny-all'
        properties: {
          priority: 130
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource webSubnetNsg 'Microsoft.Network/subnets@2021-08-01' = {
  name: '${vnetName}/web'
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
  }
}

resource appSubnetNsg 'Microsoft.Network/subnets@2021-08-01' = {
  name: '${vnetName}/app'
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
  }
}

resource dataSubnetNsg 'Microsoft.Network/subnets@2021-08-01' = {
  name: '${vnetName}/data'
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
  }
}

resource bastionResource 'Microsoft.Network/bastionHosts@2021-08-01' = {
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
    vnetResource
  ]
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'bastionPublicIp'
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    sku: {
      name: 'Standard'
    }
  }
}