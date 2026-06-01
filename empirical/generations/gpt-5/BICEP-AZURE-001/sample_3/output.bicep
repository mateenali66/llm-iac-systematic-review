targetScope = 'resourceGroup'

@description('Deployment location')
param location string = 'eastus'

@description('Virtual machine name')
param vmName string = 'devtest-ubuntu-vm'

@description('Size of the virtual machine')
param vmSize string = 'Standard_B2s'

@description('Admin username for the VM')
param adminUsername string

@description('SSH public key for the admin user (e.g., contents of ~/.ssh/id_rsa.pub)')
param sshPublicKey string

@description('CIDR source prefix allowed to SSH to the VM public IP (e.g., 203.0.113.10/32)')
param allowedSshSourceAddressPrefix string

@description('Whether to create and associate a Public IP to the VM NIC')
param enablePublicIP bool = true

@description('Optional DNS label prefix for the Public IP (must be globally unique within Azure region). Leave empty to skip.')
param dnsLabelPrefix string = ''

@description('Virtual network address space')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Subnet address prefix')
param subnetAddressPrefix string = '10.10.1.0/24'

@description('Tags to apply to all resources')
param tags object = {
  environment: 'dev-test'
  owner: adminUsername
}

var pipName = '${vmName}-pip'
var nicName = '${vmName}-nic'
var vnetName = '${vmName}-vnet'
var subnetName = 'subnet01'
var nsgName = '${vmName}-nsg'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-Trusted'
        properties: {
          description: 'Allow SSH only from the specified trusted source'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowedSshSourceAddressPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
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
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = if (enablePublicIP) {
  name: pipName
  location: location
  sku: {
    name: 'Standard'
  }
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: empty(dnsLabelPrefix) ? null : {
      domainNameLabel: toLower(dnsLabelPrefix)
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
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
          publicIPAddress: enablePublicIP ? {
            id: publicIp.id
          } : null
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
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
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
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
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

output vmId string = vm.id
output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = enablePublicIP ? publicIp.properties.ipAddress : ''