@description('Deployment location. Default is East US.')
@allowed([
  'eastus'
])
param location string = 'eastus'

@description('Name prefix for all resources.')
param prefix string = 'devtest'

@description('Virtual machine size.')
param vmSize string = 'Standard_B2s'

@description('Admin username for the VM.')
@minLength(1)
@maxLength(32)
param adminUsername string = 'azureuser'

@description('SSH public key for admin user (e.g., ssh-rsa AAAA...).')
param sshPublicKey string

@description('Create a public IP and expose the VM to the internet (SSH restricted by allowedSourceAddressPrefixes).')
param enablePublicIP bool = false

@description('CIDR ranges allowed to SSH if public IP is enabled (e.g., ["203.0.113.10/32"]). Leave empty to block SSH from internet.')
param allowedSourceAddressPrefixes array = []

@description('Virtual network address space.')
param addressSpace string = '10.20.0.0/16'

@description('Subnet address prefix.')
param subnetPrefix string = '10.20.1.0/24'

@description('OS disk size in GB.')
@minValue(30)
@maxValue(1024)
param osDiskSizeGB int = 64

@description('Optional tags to apply to all resources.')
param tags object = {}

var baseTags = {
  Environment: 'dev'
  Workload: 'developer-test'
}
var allTags = union(baseTags, tags)

var vnetName = '${prefix}-vnet'
var subnetName = 'default'
var nsgName = '${prefix}-nsg'
var publicIpName = '${prefix}-pip'
var nicName = '${prefix}-nic'
var vmName = '${prefix}-vm'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  tags: allTags
}

resource nsgRuleSsh 'Microsoft.Network/networkSecurityGroups/securityRules@2023-11-01' = if (enablePublicIP && length(allowedSourceAddressPrefixes) > 0) {
  name: 'Allow-SSH-Inbound'
  parent: nsg
  properties: {
    priority: 1000
    protocol: 'Tcp'
    access: 'Allow'
    direction: 'Inbound'
    sourceAddressPrefixes: allowedSourceAddressPrefixes
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '22'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: allTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (enablePublicIP) {
  name: publicIpName
  location: location
  tags: allTags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: toLower(replace('${vmName}${uniqueString(resourceGroup().id)}','_','-'))
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  tags: allTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
          publicIPAddress: enablePublicIP ? {
            id: publicIp.id
          } : null
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: allTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
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
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
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
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: osDiskSizeGB
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
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
output vmName string = vm.name
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = enablePublicIP ? publicIp.properties.ipAddress : ''