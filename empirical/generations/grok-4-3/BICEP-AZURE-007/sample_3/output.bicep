targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the AKS cluster')
param clusterName string

@description('Kubernetes version')
param kubernetesVersion string = '1.28.5'

@description('Resource ID of existing Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('Name of the VNet')
param vnetName string = '${clusterName}-vnet'

@description('Address prefix for the VNet')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address prefix for AKS nodes')
param aksSubnetPrefix string = '10.0.0.0/20'

@description('System node pool VM size')
param systemVmSize string = 'Standard_D4s_v5'

@description('User node pool VM size')
param userVmSize string = 'Standard_D8s_v5'

@description('System node pool count')
param systemNodeCount int = 3

@description('User node pool initial count')
param userNodeCount int = 3

@description('User node pool min count for autoscaler')
param userMinCount int = 2

@description('User node pool max count for autoscaler')
param userMaxCount int = 20

@description('SSH public key for node access (optional, disabled by default)')
param sshPublicKey string = ''

var aksSubnetName = 'aks-subnet'
var aksSubnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, aksSubnetName)

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: aksSubnetName
        properties: {
          addressPrefix: aksSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: clusterName
    enableRBAC: true
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
      outboundType: 'loadBalancer'
    }
    apiServerAccessProfile: {
      authorizedIPRanges: []
      enablePrivateCluster: false
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
      azurepolicy: {
        enabled: true
      }
    }
    agentPoolProfiles: [
      {
        name: 'system'
        count: systemNodeCount
        vmSize: systemVmSize
        osType: 'Linux'
        osDiskSizeGB: 128
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        vnetSubnetID: aksSubnetId
        enableAutoScaling: false
        nodeTaints: ['CriticalAddonsOnly=true:NoSchedule']
        availabilityZones: ['1', '2', '3']
        maxPods: 110
      }
      {
        name: 'user'
        count: userNodeCount
        vmSize: userVmSize
        osType: 'Linux'
        osDiskSizeGB: 256
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        vnetSubnetID: aksSubnetId
        enableAutoScaling: true
        minCount: userMinCount
        maxCount: userMaxCount
        availabilityZones: ['1', '2', '3']
        maxPods: 110
      }
    ]
    autoScalerProfile: {
      balanceSimilarNodeGroups: 'true'
      expander: 'random'
      maxNodeProvisionTime: '15m'
      scaleDownDelayAfterAdd: '10m'
      scaleDownUnneededTime: '10m'
      skipNodesWithSystemPods: 'true'
    }
  }
}