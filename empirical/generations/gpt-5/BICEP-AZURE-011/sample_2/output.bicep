param location string = resourceGroup().location
param projectName string = 'appgw-waf'
param adminUsername string
param adminSshPublicKey string
param vmSize string = 'Standard_B2s'
param addressPrefix string = '10.0.0.0/16'
param appGwSubnetPrefix string = '10.0.0.0/24'
param backendSubnetPrefix string = '10.0.1.0/24'
param vm1PrivateIp string = '10.0.1.4'
param vm2PrivateIp string = '10.0.1.5'
param tags object = {}

resource backendNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${projectName}-backend-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-From-AppGwSubnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: appGwSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${projectName}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'appgw-subnet'
        properties: {
          addressPrefix: appGwSubnetPrefix
        }
      }
      {
        name: 'backend-subnet'
        properties: {
          addressPrefix: backendSubnetPrefix
          networkSecurityGroup: {
            id: backendNsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${projectName}-agw-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource avset 'Microsoft.Compute/availabilitySets@2022-11-01' = {
  name: '${projectName}-avset'
  location: location
  tags: tags
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
}

resource nic1 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${projectName}-vm1-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: vm1PrivateIp
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'backend-subnet')
          }
        }
      }
    ]
  }
}

resource nic2 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${projectName}-vm2-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: vm2PrivateIp
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'backend-subnet')
          }
        }
      }
    ]
  }
}

var vm1CloudInit = '''#cloud-config
package_update: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: |
      <html><body><h1>${projectName} - VM1</h1></body></html>
runcmd:
  - systemctl enable nginx
  - systemctl restart nginx
'''

var vm2CloudInit = '''#cloud-config
package_update: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: |
      <html><body><h1>${projectName} - VM2</h1></body></html>
runcmd:
  - systemctl enable nginx
  - systemctl restart nginx
'''

resource vm1 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: '${projectName}-vm1'
  location: location
  tags: tags
  properties: {
    availabilitySet: {
      id: avset.id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${projectName}-vm1'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      }
      customData: base64(vm1CloudInit)
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
}

resource vm2 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: '${projectName}-vm2'
  location: location
  tags: tags
  properties: {
    availabilitySet: {
      id: avset.id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${projectName}-vm2'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      }
      customData: base64(vm2CloudInit)
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
}

resource wafPolicy 'Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies@2023-09-01' = {
  name: '${projectName}-wafpol'
  location: location
  tags: tags
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
}

resource appGw 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: '${projectName}-agw'
  location: location
  tags: tags
  sku: {
    name: 'WAF_v2'
    tier: 'WAF_v2'
  }
  properties: {
    firewallPolicy: {
      id: wafPolicy.id
    }
    enableHttp2: true
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 10
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'appgw-subnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: publicIp.id
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
              ipAddress: vm1PrivateIp
            }
            {
              ipAddress: vm2PrivateIp
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
          pickHostNameFromBackendAddress: false
          requestTimeout: 30
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGw.name, 'http-probe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGw.name, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGw.name, 'port80')
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
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGw.name, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGw.name, 'backendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGw.name, 'httpSettings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'http-probe'
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
        }
      }
    ]
  }
}

output applicationGatewayPublicIp string = publicIp.properties.ipAddress