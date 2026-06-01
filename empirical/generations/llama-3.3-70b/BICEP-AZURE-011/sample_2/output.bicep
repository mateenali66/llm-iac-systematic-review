param location string = resourceGroup().location
param virtualNetworkName string = 'myVnet'
param subnetName string = 'mySubnet'
param applicationGatewayName string = 'myAppGw'
param backendPoolName string = 'myBackendPool'
param frontendIpConfigurationName string = 'myFrontendIpConfiguration'
param httpSettingName string = 'myHttpSetting'
param listenerName string = 'myListener'
param ruleName string = 'myRule'
param vm1Name string = 'myVm1'
param vm2Name string = 'myVm2'

var applicationGatewaySubnet = {
  name: 'myAppGwSubnet'
  properties: {
    addressPrefix: '10.0.1.0/24'
  }
}

var virtualNetwork = {
  name: virtualNetworkName
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      applicationGatewaySubnet
    ]
  }
}

var publicIpAddress = {
  name: 'myPublicIp'
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
}

var applicationGateway = {
  name: applicationGatewayName
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfig'
        properties: {
          subnet: virtualNetwork.properties.subnets[1]
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIpConfigurationName
        properties: {
          publicIPAddress: publicIpAddress
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: httpSettingName
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: listenerName
        properties: {
          frontendIPConfiguration: {
            id: applicationGateway.properties.frontendIPConfigurations[0].id
          }
          frontendPort: {
            id: 'myFrontendPort'
          }
          protocol: 'Http'
          hostNames: [
            '*'
          ]
        }
      }
    ]
    requestRoutingRules: [
      {
        name: ruleName
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: applicationGateway.properties.httpListeners[0].id
          }
          backendAddressPool: {
            id: applicationGateway.properties.backendAddressPools[0].id
          }
          backendHttpSettings: {
            id: applicationGateway.properties.backendHttpSettingsCollection[0].id
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
    }
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  dependsOn: [
    publicIpAddress
    virtualNetwork
  ]
}

var vm1 = {
  name: vm1Name
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS2_v2'
    }
    osProfile: {
      computerName: vm1Name
      adminUsername: 'adminuser'
      adminPassword: 'P@ssw0rd1234'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '16.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: 'myNic1'
        }
      ]
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

var vm2 = {
  name: vm2Name
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS2_v2'
    }
    osProfile: {
      computerName: vm2Name
      adminUsername: 'adminuser'
      adminPassword: 'P@ssw0rd1234'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '16.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: 'myNic2'
        }
      ]
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

var nic1 = {
  name: 'myNic1'
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

var nic2 = {
  name: 'myNic2'
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig2'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

var frontendPort = {
  name: 'myFrontendPort'
  properties: {
    port: 80
  }
}

output applicationGatewayId string = applicationGateway.id
output applicationGatewayDnsName string = applicationGateway.properties.frontendIPConfigurations[0].properties.publicIPAddress.dnsSettings.fqdn

resource virtualNetworkResource 'Microsoft.Network/virtualNetworks@2021-08-01' = virtualNetwork
resource publicIpAddressResource 'Microsoft.Network/publicIPAddresses@2021-08-01' = publicIpAddress
resource applicationGatewayResource 'Microsoft.Network/applicationGateways@2021-08-01' = applicationGateway
resource vm1Resource 'Microsoft.Compute/virtualMachines@2021-11-01' = vm1
resource vm2Resource 'Microsoft.Compute/virtualMachines@2021-11-01' = vm2
resource nic1Resource 'Microsoft.Network/networkInterfaces@2021-08-01' = nic1
resource nic2Resource 'Microsoft.Network/networkInterfaces@2021-08-01' = nic2
resource frontendPortResource 'Microsoft.Network/applicationGateways/frontendPorts@2021-08-01' = frontendPort

resource backendAddressPool 'Microsoft.Network/applicationGateways/backendAddressPools@2021-08-01' = {
  name: '${applicationGatewayName}/${backendPoolName}'
  properties: {
    backendAddresses: [
      {
        ipAddress: nic1.properties.ipConfigurations[0].properties.privateIPAddress
      }
      {
        ipAddress: nic2.properties.ipConfigurations[0].properties.privateIPAddress
      }
    ]
  }
  dependsOn: [
    applicationGatewayResource
    nic1Resource
    nic2Resource
  ]
}