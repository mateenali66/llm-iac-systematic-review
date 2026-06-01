param location string = resourceGroup().location
param aksClusterName string = 'prod-aks-cluster'
param systemNodePoolName string = 'system'
param userNodePoolName string = 'user'
param systemNodeCount int = 3
param userNodeCount int = 3
param systemNodeVmSize string = 'Standard_DS2_v2'
param userNodeVmSize string = 'Standard_DS2_v2'
param kubernetesVersion string = '1.24.6'

resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-06-01' = {
  name: aksClusterName
  location: location
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: aksClusterName
    enablePrivateCluster: false
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPolicy: 'calico'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
  }
}

resource systemNodePool 'Microsoft.ContainerService/managedClusters/nodePools@2022-06-01' = {
  name: '${aksClusterName}/${systemNodePoolName}'
  properties: {
    count: systemNodeCount
    vmSize: systemNodeVmSize
    osDiskSizeGB: 30
    osDiskType: 'Ephemeral'
    mode: 'System'
  }
  dependsOn: [
    aksCluster
  ]
}

resource userNodePool 'Microsoft.ContainerService/managedClusters/nodePools@2022-06-01' = {
  name: '${aksClusterName}/${userNodePoolName}'
  properties: {
    count: userNodeCount
    vmSize: userNodeVmSize
    osDiskSizeGB: 30
    osDiskType: 'Ephemeral'
    mode: 'User'
  }
  dependsOn: [
    aksCluster
  ]
}

output aksClusterName string = aksClusterName
output systemNodePoolName string = systemNodePoolName
output userNodePoolName string = userNodePoolName