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

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-11-01' = {
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
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: false
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        enableNodePublicIP: false
        maxPods: 30
        nodeTaints: []
        scaleSetPriority: 'Regular'
        upgradeSettings: {
          maxSurge: '1'
        }
      }
      {
        name: userNodePoolName
        count: userNodeCount
        vmSize: userVmSize
        osType: 'Linux'
        mode: 'User'
        enableAutoScaling: true
        minCount: 3
        maxCount: 10
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        osDiskSizeGB: 256
        osDiskType: 'Managed'
        enableNodePublicIP: false
        maxPods: 50
        nodeTaints: []
        scaleSetPriority: 'Regular'
        upgradeSettings: {
          maxSurge: '1'
        }
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
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
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
    disableLocalAccounts: false
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: []
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
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
      authorizedIPRanges: []
      enablePrivateCluster: false
      privateDNSZone: ''
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
    workspaceCapping: {
      dailyQuotaGb: 5
    }
  }
}

output clusterName string = aksCluster.name
output clusterFqdn string = aksCluster.properties.fqdn
output nodeResourceGroup string = aksCluster.properties.nodeResourceGroup
output identityPrincipalId string = aksCluster.identity.principalId