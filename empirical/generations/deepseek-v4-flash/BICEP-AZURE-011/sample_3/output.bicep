param location string = resourceGroup().location
param vnetName string = 'appgw-vnet'
param vnetAddressPrefix string = '10.0.0.0/16'
param appgwSubnetPrefix string = '10.0.1.0/24'
param vmSubnetPrefix string = '10.0.2.0/24'
param appgwName string = 'appgw-waf'
param vmNamePrefix string = 'backend-vm'
param adminUsername string
param adminPasswordOrKey string
param vmSize string = 'Standard_DS2_v2'
param backendPort int = 80

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
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

resource appgwPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
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

resource appgw 'Microsoft.Network/applicationGateways@2023-11-01' = {
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
        name: 'frontend-port-80'
        properties: {
          port: 80
        }
      }
      {
        name: 'frontend-port-443'
        properties: {
          port: 443
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
        name: 'backend-http-settings'
        properties: {
          port: backendPort
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appgwName, 'health-probe')
          }
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
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appgwName, 'frontend-port-80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routing-rule-http'
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
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwName, 'backend-http-settings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'health-probe'
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      disabledRuleGroups: []
      exclusions: []
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    enableHttp2: true
    sslPolicy: {
      policyType: 'Predefined'
      policyName: 'AppGwSslPolicy20220101'
    }
  }
}

resource nic1 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmNamePrefix}-nic-1'
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

resource nic2 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmNamePrefix}-nic-2'
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

resource vm1 'Microsoft.Compute/virtualMachines@2023-10-02' = {
  name: '${vmNamePrefix}-1'
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
          storageAccountType: 'Premium_LRS'
        }
        caching: 'ReadWrite'
      }
    }
    osProfile: {
      computerName: '${vmNamePrefix}-1'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic1.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: ''
      }
    }
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2023-10-02' = {
  name: '${vmNamePrefix}-2'
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
          storageAccountType: 'Premium_LRS'
        }
        caching: 'ReadWrite'
      }
    }
    osProfile: {
      computerName: '${vmNamePrefix}-2'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic2.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: ''
      }
    }
  }
}