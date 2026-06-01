param location string = resourceGroup().location
param namePrefix string = 'prod'
param adminUsername string
param sshPublicKey string
param vmSize string = 'Standard_B2s'
param vnetAddressPrefix string = '10.0.0.0/16'
param appGatewaySubnetPrefix string = '10.0.1.0/24'
param backendSubnetPrefix string = '10.0.2.0/24'
param zones array = [
  '1'
  '2'
  '3'
]
param appGwMinCapacity int = 2
param appGwMaxCapacity int = 5
param sslCertData securestring
param sslCertPassword securestring
param retentionInDays int = 30
param tags object = {
  environment: 'prod'
  workload: 'web'
}

var appGwName = '${namePrefix}-agw'
var publicIpName = '${namePrefix}-agw-pip'
var vnetName = '${namePrefix}-vnet'
var appGwSubnetName = 'appgw-subnet'
var backendSubnetName = 'backend-subnet'
var backendPoolName = 'backendPool'
var httpPortName = 'port80'
var httpsPortName = 'port443'
var httpListenerName = 'listener-http'
var httpsListenerName = 'listener-https'
var httpSettingsName = 'bepool-http-settings'
var routingRuleHttpsName = 'rule-https'
var redirectRuleName = 'http-to-https-redirect'
var probeName = 'health-probe'
var nsgName = '${namePrefix}-backend-nsg'
var nic1Name = '${namePrefix}-nic-01'
var nic2Name = '${namePrefix}-nic-02'
var vm1Name = '${namePrefix}-vm-01'
var vm2Name = '${namePrefix}-vm-02'
var avSetName = '${namePrefix}-avset'
var wafPolicyName = '${namePrefix}-wafpolicy'
var logWsName = '${namePrefix}-law'
var diagName = '${appGwName}-diag'

resource logWs 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logWsName
  location: location
  tags: tags
  properties: {
    retentionInDays: retentionInDays
    features: {
      searchVersion: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    sku: {
      name: 'PerGB2018'
    }
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
    subnets: [
      {
        name: appGwSubnetName
        properties: {
          addressPrefix: appGatewaySubnetPrefix
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

resource backendNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-AppGw-to-Backend-HTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: appGatewaySubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'Deny-HTTP-from-Any'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      // set if needed
    }
  }
  zones: zones
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-09-01' = {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    policySettings: {
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      fileUploadLimitInMb: 100
      maxRequestBodySizeInKb: 128
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
  zones: zones
  sku: {
    name: 'WAF_v2'
    tier: 'WAF_v2'
  }
  properties: {
    autoscaleConfiguration: {
      minCapacity: appGwMinCapacity
      maxCapacity: appGwMaxCapacity
    }
    enableHttp2: true
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${appGwSubnetName}'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'publicFrontend'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: httpPortName
        properties: {
          port: 80
        }
      }
      {
        name: httpsPortName
        properties: {
          port: 443
        }
      }
    ]
    sslCertificates: [
      {
        name: 'sslCert1'
        properties: {
          data: sslCertData
          password: sslCertPassword
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
        properties: {
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: httpSettingsName
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 30
          probe: {
            id: '${appGw.id}/probes/${probeName}'
          }
        }
      }
    ]
    probes: [
      {
        name: probeName
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          host: '127.0.0.1'
          port: 80
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    httpListeners: [
      {
        name: httpListenerName
        properties: {
          frontendIPConfiguration: {
            id: '${appGw.id}/frontendIPConfigurations/publicFrontend'
          }
          frontendPort: {
            id: '${appGw.id}/frontendPorts/${httpPortName}'
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
      {
        name: httpsListenerName
        properties: {
          frontendIPConfiguration: {
            id: '${appGw.id}/frontendIPConfigurations/publicFrontend'
          }
          frontendPort: {
            id: '${appGw.id}/frontendPorts/${httpsPortName}'
          }
          protocol: 'Https'
          sslCertificate: {
            id: '${appGw.id}/sslCertificates/sslCert1'
          }
          requireServerNameIndication: false
        }
      }
    ]
    redirectConfigurations: [
      {
        name: redirectRuleName
        properties: {
          redirectType: 'Permanent'
          targetListener: {
            id: '${appGw.id}/httpListeners/${httpsListenerName}'
          }
          includePath: true
          includeQueryString: true
        }
      }
    ]
    requestRoutingRules: [
      {
        name: routingRuleHttpsName
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: '${appGw.id}/httpListeners/${httpsListenerName}'
          }
          backendAddressPool: {
            id: '${appGw.id}/backendAddressPools/${backendPoolName}'
          }
          backendHttpSettings: {
            id: '${appGw.id}/backendHttpSettingsCollection/${httpSettingsName}'
          }
        }
      }
      {
        name: 'routingRuleHttpRedirect'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: '${appGw.id}/httpListeners/${httpListenerName}'
          }
          redirectConfiguration: {
            id: '${appGw.id}/redirectConfigurations/${redirectRuleName}'
          }
        }
      }
    ]
    firewallPolicy: {
      id: wafPolicy.id
    }
  }
}

resource agwDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagName
  scope: appGw
  properties: {
    workspaceId: logWs.id
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
    ]
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
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${backendSubnetName}'
          }
          applicationGatewayBackendAddressPools: [
            {
              id: '${appGw.id}/backendAddressPools/${backendPoolName}'
            }
          ]
        }
      }
    ]
    networkSecurityGroup: {
      id: backendNsg.id
    }
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
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${backendSubnetName}'
          }
          applicationGatewayBackendAddressPools: [
            {
              id: '${appGw.id}/backendAddressPools/${backendPoolName}'
            }
          ]
        }
      }
    ]
    networkSecurityGroup: {
      id: backendNsg.id
    }
  }
}

resource avSet 'Microsoft.Compute/availabilitySets@2023-09-01' = {
  name: avSetName
  location: location
  tags: tags
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
  sku: {
    name: 'Aligned'
  }
}

var cloudInit = base64('''
#cloud-config
package_update: true
package_upgrade: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: |
      <html><body><h1>Welcome from $(hostname)</h1></body></html>
runcmd:
  - systemctl enable nginx
  - systemctl restart nginx
''')

resource vm1 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm1Name
  location: location
  tags: tags
  properties: {
    availabilitySet: {
      id: avSet.id
    }
    hardwareProfile: {
      vmSize: vmSize
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
      customData: cloudInit
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
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
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm2Name
  location: location
  tags: tags
  properties: {
    availabilitySet: {
      id: avSet.id
    }
    hardwareProfile: {
      vmSize: vmSize
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
      customData: cloudInit
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
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
  }
}