param location string = resourceGroup().location
param vnetName string = 'appgw-vnet'
param vnetAddressPrefix string = '10.0.0.0/16'
param appgwSubnetPrefix string = '10.0.1.0/24'
param vmSubnetPrefix string = '10.0.2.0/24'
param appgwName string = 'appgw-waf'
param vmNamePrefix string = 'backend-vm'
param adminUsername string = 'azureuser'
param adminPassword string = '@{securestring}'
param vmSize string = 'Standard_DS2_v2'

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
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
        name: 'appgw-subnet'
        properties: {
          addressPrefix: appgwSubnetPrefix
        }
      }
      {
        name: 'vm-subnet'
        properties: {
          addressPrefix: vmSubnetPrefix
        }
      }
    ]
  }
}

resource appgwPublicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${appgwName}-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource appgwIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${appgwName}-identity'
  location: location
}

resource appgw 'Microsoft.Network/applicationGateways@2023-04-01' = {
  name: appgwName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appgwIdentity.id}': {}
    }
  }
  sku: {
    name: 'WAF_v2'
    tier: 'WAF_v2'
    capacity: 2
  }
  properties: {
    gatewayIPConfigurations: [
      {
        name: 'appgw-ip-config'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'appgw-subnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appgw-frontend-ip'
        properties: {
          publicIPAddress: {
            id: appgwPublicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port-80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backend-pool'
        properties: {
          backendAddresses: [
            {
              ipAddress: '10.0.2.4'
            }
            {
              ipAddress: '10.0.2.5'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'http-settings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'http-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appgwName, 'appgw-frontend-ip')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appgwName, 'port-80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routing-rule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appgwName, 'http-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appgwName, 'backend-pool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwName, 'http-settings')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
    enableHttp2: false
    sslPolicy: {
      policyType: 'Predefined'
      policyName: 'AppGwSslPolicy20220101'
    }
  }
}

resource vmNic1 'Microsoft.Network/networkInterfaces@2023-04-01' = {
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
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.2.4'
        }
      }
    ]
  }
}

resource vmNic2 'Microsoft.Network/networkInterfaces@2023-04-01' = {
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
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.2.5'
        }
      }
    ]
  }
}

resource vm1 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${vmNamePrefix}1'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
          id: vmNic1.id
        }
      ]
    }
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${vmNamePrefix}2'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
          id: vmNic2.id
        }
      ]
    }
  }
}