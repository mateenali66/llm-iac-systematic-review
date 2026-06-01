@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the Virtual Network.')
param vnetName string = 'agw-vnet'

@description('Name of the Application Gateway.')
param appGatewayName string = 'agw-waf'

@description('Name prefix for the virtual machines.')
param vmNamePrefix string = 'vm-backend'

@description('Admin username for the VMs.')
param adminUsername string = 'azureuser'

@description('Admin password for the VMs.')
@secure()
param adminPassword string

@description('SKU size for Application Gateway v2.')
param appGatewaySkuSize string = 'WAF_v2'

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'appgw-subnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'vm-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${appGatewayName}-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: appGatewayName
  location: location
  sku: {
    name: appGatewaySkuSize
    tier: 'WAF_v2'
    capacity: 2
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'appgw-subnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool'
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpSettings'
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
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rule1'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'backendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'httpSettings')
          }
          priority: 100
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource vm1Nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmNamePrefix}1-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'vm-subnet')
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource vm2Nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmNamePrefix}2-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'vm-subnet')
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource vm1 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: '${vmNamePrefix}1'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: '${vmNamePrefix}1'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm1Nic.id
        }
      ]
    }
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: '${vmNamePrefix}2'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: '${vmNamePrefix}2'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm2Nic.id
        }
      ]
    }
  }
}

resource backendPoolUpdate 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: appGatewayName
  location: location
  properties: {
    backendAddressPools: [
      {
        name: 'backendPool'
        properties: {
          backendAddresses: [
            {
              ipAddress: vm1Nic.properties.ipConfigurations[0].properties.privateIPAddress
            }
            {
              ipAddress: vm2Nic.properties.ipConfigurations[0].properties.privateIPAddress
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    appGateway
    vm1
    vm2
  ]
}