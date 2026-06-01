param vmName string = 'devvm-jammy-01'
param adminUsername string
@description('SSH public key in OpenSSH format (e.g., ssh-ed25519 AAAA... or ssh-rsa AAAA...)')
param adminPublicKey string
@description('CIDR block allowed to SSH into the VM (e.g., 203.0.113.0/24). Do NOT use 0.0.0.0/0.')
param sshSourceAddressPrefix string
@description('Address space for the virtual network.')
param virtualNetworkCidr string = '10.10.0.0/16'
@description('Address space for the subnet.')
param subnetCidr string = '10.10.1.0/24'
@description('OS disk size in GB.')
@minValue(32)
param osDiskSizeGB int = 64
@description('OS disk storage account type (StandardSSD_LRS for balanced cost/perf).')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
  'Standard_LRS'
  'PremiumV2_LRS'
])
param osDiskStorageSku string = 'StandardSSD_LRS'
@description('Optional resource tags.')
param tags object = {
  environment: 'dev'
  workload: 'test'
}

var location = 'eastus'
var vnetName = '${vmName}-vnet'
var subnetName = 'subnet01'
var nsgName = '${vmName}-nsg'
var nicName = '${vmName}-nic'
var pipName = '${vmName}-pip'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-Trusted'
        properties: {
          access: 'Allow'
          description: 'Allow SSH from trusted source'
          direction: 'Inbound'
          priority: 1000
          protocol: 'Tcp'
          sourceAddressPrefix: sshSourceAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkCidr
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetCidr
          networkSecurityGroup: {
            id: nsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 15
    dnsSettings: {
      domainNameLabel: toLower(replace('${vmName}-${uniqueString(resourceGroup().id)}','_','-'))
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    enableIPForwarding: false
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          assessmentMode: 'AutomaticByPlatform'
        }
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
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
        caching: 'ReadWrite'
        diskSizeGB: osDiskSizeGB
        managedDisk: {
          storageAccountType: osDiskStorageSku
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output publicIpAddress string = publicIp.properties.ipAddress
output sshConnectionString string = 'ssh ${adminUsername}@${publicIp.properties.dnsSettings.fqdn}'