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

resource aksResource 'Microsoft.ContainerService/managedClusters@2022-06-02' = {
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
  dependsOn: []
}

resource systemNodePool 'Microsoft.ContainerService/managedClusters/nodePools@2022-06-02' = {
  name: '${aksClusterName}/${systemNodePoolName}'
  properties: {
    count: systemNodeCount
    vmSize: systemNodeVmSize
    mode: 'System'
    osDiskSizeGB: 128
    osDiskType: 'Managed'
    type: 'VirtualMachineScaleSets'
    enableAutoScaling: false
    maxCount: systemNodeCount
    minCount: systemNodeCount
    maxPods: 110
  }
  dependsOn: [
    aksResource
  ]
}

resource userNodePool 'Microsoft.ContainerService/managedClusters/nodePools@2022-06-02' = {
  name: '${aksClusterName}/${userNodePoolName}'
  properties: {
    count: userNodeCount
    vmSize: userNodeVmSize
    mode: 'User'
    osDiskSizeGB: 128
    osDiskType: 'Managed'
    type: 'VirtualMachineScaleSets'
    enableAutoScaling: false
    maxCount: userNodeCount
    minCount: userNodeCount
    maxPods: 110
  }
  dependsOn: [
    aksResource
  ]
}

output aksClusterName string = aksResource.name
output systemNodePoolId string = systemNodePool.id
output userNodePoolId string = userNodePool.id