targetScope = 'resourceGroup'

param location string = resourceGroup().location
param clusterName string = 'aks-${uniqueString(resourceGroup().id)}'
param dnsPrefix string = 'aks-dns'
param kubernetesVersion string = '1.28'
param systemNodePoolName string = 'system'
param userNodePoolName string = 'user'
param systemNodeCount int = 3
param userNodeCount int = 3
param systemVmSize string = 'Standard_D4s_v5'
param userVmSize string = 'Standard_D4s_v5'
param maxPods int = 30
param networkPlugin string = 'azure'
param networkPolicy string = 'azure'
param serviceCidr string = '10.0.0.0/16'
param dnsServiceIP string = '10.0.0.10'
param dockerBridgeCidr string = '172.17.0.1/16'
param vnetAddressPrefix string = '10.1.0.0/16'
param aksSubnetPrefix string = '10.1.0.0/20'
param aciSubnetPrefix string = '10.1.16.0/20'

var aksSubnetName = 'aks-subnet'
var aciSubnetName = 'aci-subnet'
var identityName = '${clusterName}-identity'
var vnetName = '${clusterName}-vnet'

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-02-01' = {
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
        name: aksSubnetName
        properties: {
          addressPrefix: aksSubnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
            {
              service: 'Microsoft.Storage'
            }
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: aciSubnetName
        properties: {
          addressPrefix: aciSubnetPrefix
          delegations: [
            {
              name: 'aciDelegation'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-02-01' existing = {
  name: aksSubnetName
  parent: virtualNetwork
}

resource aciSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-02-01' existing = {
  name: aciSubnetName
  parent: virtualNetwork
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-07-02-preview' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: systemNodePoolName
        count: systemNodeCount
        vmSize: systemVmSize
        osDiskSizeGB: 128
        osDiskType: 'Ephemeral'
        vnetSubnetID: aksSubnet.id
        maxPods: maxPods
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        maxCount: 10
        minCount: systemNodeCount
        enableAutoScaling: true
        mode: 'System'
        osType: 'Linux'
        enableNodePublicIP: false
        enableFIPS: false
        kubeletDiskType: 'OS'
      }
      {
        name: userNodePoolName
        count: userNodeCount
        vmSize: userVmSize
        osDiskSizeGB: 128
        osDiskType: 'Ephemeral'
        vnetSubnetID: aksSubnet.id
        maxPods: maxPods
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        maxCount: 20
        minCount: userNodeCount
        enableAutoScaling: true
        mode: 'User'
        osType: 'Linux'
        enableNodePublicIP: false
        enableFIPS: false
        kubeletDiskType: 'OS'
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: networkPolicy
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      dockerBridgeCidr: dockerBridgeCidr
      outboundType: 'loadBalancer'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
      authorizedIPRanges: []
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: ''
        }
      }
      azurepolicy: {
        enabled: true
      }
      httpApplicationRouting: {
        enabled: false
      }
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }
    disableLocalAccounts: true
    securityProfile: {
      azureKeyVaultKms: {
        enabled: false
      }
      defender: {
        logAnalyticsWorkspaceResourceId: ''
        securityMonitoring: {
          enabled: true
        }
      }
      workloadIdentity: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, userAssignedIdentity.id, 'Network Contributor')
  scope: aksSubnet
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output clusterName string = aksCluster.name
output clusterId string = aksCluster.id
output kubeletIdentityObjectId string = aksCluster.identity.userAssignedIdentities[userAssignedIdentity.id].principalId
output aksSubnetId string = aksSubnet.id
output aciSubnetId string = aciSubnet.id