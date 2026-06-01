param location string = resourceGroup().location
param appGatewayName string = 'appgw-waf-v2'
param vmNamePrefix string = 'backend-vm'
param adminUsername string = 'azureuser'
param adminPassword string = 'P@ssw0rd1234!'
param virtualNetworkName string = 'appgw-vnet'
param subnetName string = 'appgw-subnet'
param backendSubnetName string = 'backend-subnet'

var appGatewaySubnetPrefix = '10.0.0.0/24'
var backendSubnetPrefix = '10.0.1.0/24'
var frontendPort = 80
var backendPort = 80
var skuName = 'WAF_v2'
var tier = 'WAF_v2'
var capacity = 2
var wafMode = 'Detection'

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
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
          addressPrefix: appGatewaySubnetPrefix
          serviceEndpoints: []
        }
      }
      {
        name: backendSubnetName
        properties: {
          addressPrefix: backendSubnetPrefix
          serviceEndpoints: []
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: '${appGatewayName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2022-07-01' = {
  name: appGatewayName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: skuName
      tier: tier
      capacity: capacity
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'appGatewayFrontendPort'
        properties: {
          port: frontendPort
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        properties: {
          backendAddresses: [
            {
              ipAddress: vm1.properties.ipConfigurations[0].properties.privateIPAddress
            }
            {
              ipAddress: vm2.properties.ipConfigurations[0].properties.privateIPAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appGatewayBackendHttpSettings'
        properties: {
          port: backendPort
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
        }
      }
    ]
    httpListeners: [
      {
        name: 'appGatewayHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'appGatewayFrontendPort')
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
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'appGatewayHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'appGatewayBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'appGatewayBackendHttpSettings')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: wafMode
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
    enableHttp2: false
  }
  dependsOn: [
    pip
    vnet
    vm1
    vm2
  ]
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${backendSubnetName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: appGatewaySubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowSSH'
        properties: {
          priority: 1001
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureCloud'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource backendSubnetRef 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: '${virtualNetworkName}/${backendSubnetName}'
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
  }
  dependsOn: [
    vnet
    nsg
  ]
}

resource vm1 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: '${vmNamePrefix}-1'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: '${vmNamePrefix}-1'
      adminUsername: adminUsername
      adminPassword: adminPassword
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
          id: nic1.id
        }
      ]
    }
  }
  dependsOn: [
    nic1
  ]
}

resource vm2 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: '${vmNamePrefix}-2'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: '${vmNamePrefix}-2'
      adminUsername: adminUsername
      adminPassword: adminPassword
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
          id: nic2.id
        }
      ]
    }
  }
  dependsOn: [
    nic2
  ]
}

resource nic1 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${vmNamePrefix}-1-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, backendSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource nic2 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${vmNamePrefix}-2-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, backendSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}