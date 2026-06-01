param location string = resourceGroup().location
param virtualNetworkName string = 'appgwvnet'
param subnetName string = 'appgwsubnet'
param applicationGatewayName string = 'appgw'
param backendPoolName string = 'backendpool'
param frontendIPConfigurationName string = 'frontendip'
param gatewayIPConfigurationName string = 'gatewayip'
param frontendPortName string = 'frontendport'
param httpSettingName string = 'httpsetting'
param listenerName string = 'listener'
param ruleName string = 'rule'
param webApplicationFirewallConfigurationName string = 'wafconfig'

var applicationGatewaySubnetAddressPrefix = '10.0.1.0/24'
var backendSubnetAddressPrefix = '10.0.2.0/24'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: virtualNetworkName
  location: location
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
          addressPrefix: applicationGatewaySubnetAddressPrefix
        }
      }
      {
        name: 'backendsubnet'
        properties: {
          addressPrefix: backendSubnetAddressPrefix
        }
      }
    ]
  }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'appgwpublicip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
  sku: {
    name: 'Standard'
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2021-08-01' = {
  name: applicationGatewayName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    gatewayIPConfigurations: [
      {
        name: gatewayIPConfigurationName
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIPConfigurationName
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
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
            id: applicationGateway.properties.frontendPorts[0].id
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
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.1'
    }
  }
  dependsOn: [
    publicIP
    virtualNetwork
  ]
}

resource frontendPort 'Microsoft.Network/applicationGateways/frontendPorts@2021-08-01' = {
  name: frontendPortName
  properties: {
    port: 80
  }
  parent: applicationGateway
}

resource vm1 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: 'vm1'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS2_v2'
    }
    osProfile: {
      computerName: 'vm1'
      adminUsername: 'adminuser'
      adminPassword: 'P@ssw0rd1234!'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
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
          id: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/networkInterfaces/vm1nic'
        }
      ]
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource vm2 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: 'vm2'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS2_v2'
    }
    osProfile: {
      computerName: 'vm2'
      adminUsername: 'adminuser'
      adminPassword: 'P@ssw0rd1234!'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
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
          id: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/networkInterfaces/vm2nic'
        }
      ]
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource vm1nic 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: 'vm1nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[1].id
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource vm2nic 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: 'vm2nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig2'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[1].id
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource backendPoolUpdate 'Microsoft.Network/applicationGateways/backendAddressPools@2021-08-01' = {
  name: 'backendpool'
  properties: {
    backendAddresses: [
      {
        ipAddress: vm1nic.properties.ipConfigurations[0].properties.privateIPAddress
      }
      {
        ipAddress: vm2nic.properties.ipConfigurations[0].properties.privateIPAddress
      }
    ]
  }
  parent: applicationGateway
  dependsOn: [
    applicationGateway
    vm1nic
    vm2nic
  ]
}