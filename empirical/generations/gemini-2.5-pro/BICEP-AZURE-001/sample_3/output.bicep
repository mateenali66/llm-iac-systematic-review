@description('The prefix for all resource names.')
param namePrefix string = 'devtest'

@description('The Azure region where the resources will be deployed.')
param location string = 'eastus'

@description('The size of the virtual machine.')
param vmSize string = 'Standard_B2s'

@description('The administrator username for the virtual machine.')
param adminUsername string = 'azureadmin'

@description('The SSH public key for authenticating to the virtual machine.')
@secure()
param adminSshPublicKey string

@description('The source address prefix for the SSH inbound rule. Use "*" for any source.')
param sshSourceAddressPrefix string = 'Internet'

var uniqueSuffix = uniqueString(resourceGroup().id)
var storageAccountName = '${namePrefix}diag${uniqueSuffix}'
var publicIpAddressName = '${namePrefix}-pip'
var publicIpDnsName = '${namePrefix}-${uniqueSuffix}'
var networkSecurityGroupName = '${namePrefix}-nsg'
var virtualNetworkName = '${namePrefix}-vnet'
var networkInterfaceName = '${namePrefix}-nic'
var virtualMachineName = '${namePrefix}-vm'
var subnetName = 'default'
var vnetAddressPrefix = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.0.0/24'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2023-05-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: publicIpDnsName
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourceAddressPrefix: sshSourceAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: virtualNetworkName
  location: location
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
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddress.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }