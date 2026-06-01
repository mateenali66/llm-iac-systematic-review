param location string = resourceGroup().location
param aksClusterName string = 'prod-aks-cluster'
param systemNodePoolName string = 'system'
param userNodePoolName string = 'user'
param systemNodeCount int = 3
param userNodeCount int = 3
param systemNodeVmSize string = 'Standard_DS2_v2'
param userNodeVmSize string = 'Standard_DS2_v2'
param kubernetesVersion string = '1.24.6'
param networkPolicy string = 'calico'
param loadBalancerSku string = 'standard'

resource aksResource 'Microsoft.ContainerService/managedClusters@2022-06-01' = {
  name: aksClusterName
  location: location
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: aksClusterName
    networkProfile: {
      networkPolicy: networkPolicy
      loadBalancerSku: loadBalancerSku
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
}

resource systemNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2022-06-01' = {
  name: '${aksClusterName}/${systemNodePoolName}'
  properties: {
    count: systemNodeCount
    vmSize: systemNodeVmSize
    osDiskSizeGB: 30
    osDiskType: 'Managed'
    type: 'VirtualMachineScaleSets'
    mode: 'System'
    enableAutoScaling: false
    maxPods: 30
    minCount: systemNodeCount
    maxCount: systemNodeCount
  }
  dependsOn: [
    aksResource
  ]
}

resource userNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2022-06-01' = {
  name: '${aksClusterName}/${userNodePoolName}'
  properties: {
    count: userNodeCount
    vmSize: userNodeVmSize
    osDiskSizeGB: 30
    osDiskType: 'Managed'
    type: 'VirtualMachineScaleSets'
    mode: 'User'
    enableAutoScaling: false
    maxPods: 30
    minCount: userNodeCount
    maxCount: userNodeCount
  }
  dependsOn: [
    aksResource
  ]
}

output aksClusterId string = aksResource.id
output systemNodePoolId string = systemNodePool.id
output userNodePoolId string = userNodePool.id