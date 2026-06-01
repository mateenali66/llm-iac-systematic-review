param location string = resourceGroup().location
param clusterName string = 'aks-${uniqueString(resourceGroup().id)}'
param dnsPrefix string = toLower('${clusterName}-dns')
param kubernetesVersion string = '1.29.7'
param systemNodePoolName string = 'systempool'
param systemNodeCount int = 3
param systemVmSize string = 'Standard_D4s_v3'
param userNodePoolName string = 'userpool'
param userNodeCount int = 5
param userVmSize string = 'Standard_D8s_v3'
param adminUsername string = 'azureuser'
param sshPublicKey string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: systemNodePoolName
        count: systemNodeCount
        vmSize: systemVmSize
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        enableNodePublicIP: false
        enableAutoScaling: false
        minCount: 3
        maxCount: 5
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
      {
        name: userNodePoolName
        count: userNodeCount
        vmSize: userVmSize
        osDiskSizeGB: 256
        osDiskType: 'Managed'
        osType: 'Linux'
        mode: 'User'
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        enableNodePublicIP: false
        enableAutoScaling: true
        minCount: 3
        maxCount: 20
      }
    ]
    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: []
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      azureDefender: {
        enabled: true
      }
      workloadIdentity: {
        enabled: true
      }
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    nodeResourceGroup: '${clusterName}-nodes'
    enablePodSecurityPolicy: false
    storageProfile: {
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
      enablePrivateClusterPublicFQDN: false
    }
  }
  tags: {
    Environment: 'Production'
    ManagedBy: 'Bicep'
  }
}

output clusterId string = aksCluster.id
output clusterFqdn string = aksCluster.properties.fqdn
output clusterNodeResourceGroup string = aksCluster.properties.nodeResourceGroup