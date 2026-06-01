param location string = resourceGroup().location
param clusterName string = 'aks-${uniqueString(resourceGroup().id)}'
param dnsPrefix string = toLower('${clusterName}-dns')
param kubernetesVersion string = '1.28.3'
param systemNodePoolName string = 'systempool'
param systemNodeCount int = 3
param systemVmSize string = 'Standard_D4s_v3'
param userNodePoolName string = 'userpool'
param userNodeCount int = 5
param userVmSize string = 'Standard_D8s_v3'
param adminUsername string = 'azureuser'
param sshPublicKey string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
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
        enableNodePublicIP: false
        enableAutoScaling: false
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
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
        enableNodePublicIP: false
        enableAutoScaling: true
        minCount: 3
        maxCount: 10
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeTaints: []
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
    addonProfiles: {
      azurepolicy: {
        enabled: true
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.id
        }
      }
    }
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: []
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'law-${clusterName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output aksClusterName string = aksCluster.name
output aksClusterFqdn string = aksCluster.properties.fqdn
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id