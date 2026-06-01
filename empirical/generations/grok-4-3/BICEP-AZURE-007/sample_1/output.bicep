targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the AKS cluster')
param clusterName string = 'aks-prod-cluster'

@description('Kubernetes version')
param kubernetesVersion string = '1.28.5'

@description('Resource ID of existing Log Analytics workspace for monitoring')
param logAnalyticsWorkspaceId string

@description('VM size for system node pool')
param systemNodeVmSize string = 'Standard_D4s_v5'

@description('VM size for user node pool')
param userNodeVmSize string = 'Standard_D8s_v5'

@description('Number of nodes in system node pool')
param systemNodeCount int = 3

@description('Number of nodes in user node pool')
param userNodeCount int = 5

@description('Minimum number of nodes for user node pool autoscaler')
param userMinCount int = 3

@description('Maximum number of nodes for user node pool autoscaler')
param userMaxCount int = 20

@description('Enable Azure AD integration and RBAC')
param enableAzureRbac bool = true

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${clusterName}-dns'
    enableRBAC: true
    aadProfile: enableAzureRbac ? {
      managed: true
      enableAzureRBAC: true
    } : null
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
    apiServerAccessProfile: {
      enablePrivateCluster: false
      authorizedIPRanges: []
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
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
        maxCount: 6
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeLabels: {
          'nodepool-type': 'system'
        }
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
    ]
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    disableLocalAccounts: true
  }
}

resource userNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2024-02-01' = {
  parent: aksCluster
  name: 'user'
  properties: {
    count: userNodeCount
    vmSize: userNodeVmSize
    osType: 'Linux'
    osDiskSizeGB: 256
    type: 'VirtualMachineScaleSets'
    mode: 'User'
    enableAutoScaling: true
    minCount: userMinCount
    maxCount: userMaxCount
    availabilityZones: [
      '1'
      '2'
      '3'
    ]
    nodeLabels: {
      'nodepool-type': 'user'
      'workload-type': 'microservices'
    }
    maxPods: 110
  }
}