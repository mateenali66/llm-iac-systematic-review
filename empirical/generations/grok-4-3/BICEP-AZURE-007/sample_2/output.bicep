targetScope = 'resourceGroup'

@description('AKS cluster name')
param clusterName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Kubernetes version')
param kubernetesVersion string = '1.28.5'

@description('System node pool VM size')
param systemNodeVmSize string = 'Standard_D4s_v5'

@description('User node pool VM size')
param userNodeVmSize string = 'Standard_D8s_v5'

@description('System node pool initial count')
param systemNodeCount int = 3

@description('User node pool initial count')
param userNodeCount int = 5

@description('Enable Azure RBAC for Kubernetes')
param enableAzureRbac bool = true

@description('Resource ID of Log Analytics workspace for monitoring')
param logAnalyticsWorkspaceId string

resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: clusterName
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: enableAzureRbac
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
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
        vmSize: systemNodeVmSize
        osType: 'Linux'
        osDiskSizeGB: 128
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        enableAutoScaling: true
        minCount: 3
        maxCount: 10
        maxPods: 110
        nodeLabels: {
          'nodepool-type': 'system'
        }
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
    ]
    apiServerAccessProfile: {
      authorizedIPRanges: []
      enablePrivateCluster: false
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
  }
}

resource userNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2024-02-01' = {
  parent: aks
  name: 'user'
  properties: {
    count: userNodeCount
    vmSize: userNodeVmSize
    osType: 'Linux'
    osDiskSizeGB: 256
    type: 'VirtualMachineScaleSets'
    mode: 'User'
    enableAutoScaling: true
    minCount: 3
    maxCount: 50
    maxPods: 110
    nodeLabels: {
      'nodepool-type': 'user'
      'workload-type': 'microservices'
    }
    availabilityZones: [
      '1'
      '2'
      '3'
    ]
  }
  dependsOn: [
    aks
  ]
}