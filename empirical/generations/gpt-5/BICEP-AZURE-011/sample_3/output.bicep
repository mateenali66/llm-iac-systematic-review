param location string = resourceGroup().location
param namePrefix string = 'agw-waf-prod'
param tags object = {
  environment: 'prod'
}
param vnetAddressPrefix string = '10.0.0.0/16'
param agwSubnetPrefix string = '10.0.0.0/24'
param backendSubnetPrefix string = '10.0.1.0/24'
param backendIp1 string = '10.0.1.4'
param backendIp2 string = '10.0.1.5'
@minLength(3)
param adminUsername string
@description('SSH public key in OpenSSH format (e.g., ssh-ed25519/ssh-rsa ...).')
param sshPublicKey string
@description('CIDR allowed to SSH to backend VMs')
param adminAllowedCidr string = '0.0.0.0/0'
@allowed([
  'Standard_B2ms'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
])
param vmSize string = 'Standard_D2s_v5'

var vnetName = '${namePrefix}-vnet'
var agwSubnetName = 'agw-snet'
var backendSubnetName = 'backend-snet'
var pipName = '${namePrefix}-pip'
var appGwName = '${namePrefix}-agw'
var wafPolicyName = '${namePrefix}-wafpol'
var nsgName = '${namePrefix}-backend-nsg'
var nic1Name = '${namePrefix}-vm1-nic'
var nic2Name = '${namePrefix}-vm2-nic'
var vm1Name = '${namePrefix}-vm1'
var vm2Name = '${namePrefix}-vm2'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Admin'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: adminAllowedCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-HTTP-From-AGW-Subnet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: agwSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource agwSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  name: '${vnet.name}/${agwSubnetName}'
  properties: {
    addressPrefix: agwSubnetPrefix
  }
}

resource backendSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  name: '${vnet.name}/${backendSubnetName}'
  properties: {
    addressPrefix: backendSubnetPrefix
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: toLower(replace('${namePrefix}-${uniqueString(resourceGroup().id)}', '_', '-'))
    }
  }
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-09-01' = {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: 'Enabled'
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
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
  name: appGwName
  location: location
  tags: tags
  sku: {
    name: 'WAF_v2'
    tier: 'WAF_v2'
  }
  properties: {
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
            id: agwSubnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontend'
        properties: {
          publicIPAddress: {
            id: pip.id
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
              ipAddress: backendIp1
            }
            {
              ipAddress: backendIp2
            }
          ]
        }
      }
    ]
    probes: [
      {
        name: 'httpProbe'
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          port: 80
          match: {
            body: null
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpSetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: false
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGw.name, 'httpProbe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGw.name, 'appGwPublicFrontend')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGw.name, 'port80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
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
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGw.name, 'httpSetting')
          }
        }
      }
    ]
    firewallPolicy: {
      id: wafPolicy.id
    }
  }
}

resource nic1 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nic1Name
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: backendIp1
          subnet: {
            id: backendSubnet.id
          }
        }
      }
    ]
  }
}

resource nic2 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nic2Name
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: backendIp2
          subnet: {
            id: backendSubnet.id
          }
        }
      }
    ]
  }
}

var cloudInitBase = ''
  + '#cloud-config\n'
  + 'package_update: true\n'
  + 'packages:\n'
  + '  - nginx\n'
  + 'write_files:\n'
  + '  - path: /var/www/html/index.html\n'
  + '    permissions: "0644"\n'
  + '    owner: root:root\n'
  + '    content: |\n'
  + '      <html><body><h1>${HOSTNAME}</h1><p>Served by ${HOSTNAME}</p></body></html>\n'
  + 'runcmd:\n'
  + '  - systemctl enable nginx\n'
  + '  - systemctl restart nginx\n'

resource vm1 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm1Name
  location: location
  tags: tags
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
      }
    }
    osProfile: {
      computerName: vm1Name
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
      customData: base64(cloudInitBase)
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

resource vm2 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm2Name
  location: location
  tags: tags
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
      }
    }
    osProfile: {
      computerName: vm2Name
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
      customData: base64(cloudInitBase)
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

output applicationGatewayId string = appGw.id
output publicIpFqdn string = pip.properties.dnsSettings.fqdn
output vm1PrivateIp string = backendIp1
output vm2PrivateIp string = backendIp2