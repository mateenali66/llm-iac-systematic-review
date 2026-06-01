param location string = resourceGroup().location
param vnetName string = 'appgw-vnet'
param vnetAddressPrefix string = '10.0.0.0/16'
param appgwSubnetName string = 'appgw-subnet'
param appgwSubnetPrefix string = '10.0.1.0/24'
param backendSubnetName string = 'backend-subnet'
param backendSubnetPrefix string = '10.0.2.0/24'
param appgwName string = 'appgw-waf'
param appgwPublicIpName string = 'appgw-public-ip'
param vmNamePrefix string = 'backend-vm'
param vmAdminUsername string = 'azureuser'
param vmAdminPassword string = 'P@ssw0rd1234!'
param vmSize string = 'Standard_DS2_v2'
param vmImagePublisher string = 'MicrosoftWindowsServer'
param vmImageOffer string = 'WindowsServer'
param vmImageSku string = '2019-Datacenter'
param vmImageVersion string = 'latest'
param nsgName string = 'backend-nsg'

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
        name: appgwSubnetName
        properties: {
          addressPrefix: appgwSubnetPrefix
        }
      }
      {
        name: backendSubnetName
        properties: {
          addressPrefix: backendSubnetPrefix
        }
      }
    ]
  }
}

resource appgwSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  name: appgwSubnetName
  parent: vnet
}

resource backendSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  name: backendSubnetName
  parent: vnet
}

resource appgwPublicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: appgwPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource backendNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPFromAppGW'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: appgwSubnet.properties.addressPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTPSFromAppGW'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appgwSubnet.properties.addressPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllOtherInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource backendNic1 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${vmNamePrefix}-nic-1'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: backendSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: backendNsg.id
    }
  }
}

resource backendNic2 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${vmNamePrefix}-nic-2'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: backendSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: backendNsg.id
    }
  }
}

resource backendVm1 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${vmNamePrefix}-1'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmNamePrefix}-1'
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: vmImageSku
        version: vmImageVersion
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
          id: backendNic1.id
        }
      ]
    }
  }
}

resource backendVm2 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${vmNamePrefix}-2'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmNamePrefix}-2'
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: vmImageSku
        version: vmImageVersion
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
          id: backendNic2.id
        }
      ]
    }
  }
}

resource appgw 'Microsoft.Network/applicationGateways@2023-04-01' = {
  name: appgwName
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appgwIpConfig'
        properties: {
          subnet: {
            id: appgwSubnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appgwFrontendIpConfig'
        properties: {
          publicIPAddress: {
            id: appgwPublicIp.id
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
        properties: {
          backendAddresses: [
            {
              ipAddress: backendNic1.properties.ipConfigurations[0].properties.privateIPAddress
            }
            {
              ipAddress: backendNic2.properties.ipConfigurations[0].properties.privateIPAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpSettings'
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
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appgwName, 'appgwFrontendIpConfig')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appgwName, 'port80')
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
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appgwName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appgwName, 'backendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwName, 'httpSettings')
          }
        }
      }
    ]
  }
  dependsOn: [
    backendVm1
    backendVm2
  ]
}