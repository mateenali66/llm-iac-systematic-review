targetScope = 'resourceGroup'

param location string = resourceGroup().location
param clusterName string = 'aks-cluster-${uniqueString(resourceGroup().id)}'
param dnsPrefix string = 'aks-dns-${uniqueString(resourceGroup().id)}'
param kubernetesVersion string = '1.27.3'
param systemNodePoolName string = 'system'
param userNodePoolName string = 'user'
param systemNodeCount int = 3
param userNodeCount int = 3
param systemVmSize string = 'Standard_D4s_v5'
param userVmSize string = 'Standard_D4s_v5'
param adminUsername string = 'azureuser'

var sshPublicKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC' // Replace with actual SSH public key

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-06-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: systemNodePoolName
        count: systemNodeCount
        vmSize: systemVmSize
        osDiskSizeGB: 128
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        enableAutoScaling: false
        enableNodePublicIP: false
        enableFIPS: false
        kubeletDiskType: 'OS'
        maxPods: 110
        orchestratorVersion: kubernetesVersion
        osDiskType: 'Ephemeral'
        vnetSubnetID: virtualNetwork.properties.subnets[0].id
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeLabels: {
          'kubernetes.azure.com/mode': 'system'
        }
        nodeTaints: []
        proximityPlacementGroupID: ''
        spotMaxPrice: -1
        tags: {}
      }
      {
        name: userNodePoolName
        count: userNodeCount
        vmSize: userVmSize
        osDiskSizeGB: 128
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        enableAutoScaling: true
        minCount: 1
        maxCount: 10
        enableNodePublicIP: false
        enableFIPS: false
        kubeletDiskType: 'OS'
        maxPods: 110
        orchestratorVersion: kubernetesVersion
        osDiskType: 'Ephemeral'
        vnetSubnetID: virtualNetwork.properties.subnets[0].id
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeLabels: {
          'kubernetes.azure.com/mode': 'user'
        }
        nodeTaints: []
        proximityPlacementGroupID: ''
        spotMaxPrice: -1
        tags: {}
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
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
      authorizedIPRanges: []
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
      azurepolicy: {
        enabled: true
      }
      httpApplicationRouting: {
        enabled: false
      }
    }
    autoScalerProfile: {
      balanceSimilarNodeGroups: 'true'
      expander: 'priority'
      maxEmptyBulkDelete: '10'
      maxGracefulTerminationSec: '600'
      maxNodeProvisionTime: '15m'
      maxTotalUnreadyPercentage: '45'
      newPodScaleUpDelay: '0s'
      okTotalUnreadyCount: '3'
      scaleDownDelayAfterAdd: '10m'
      scaleDownDelayAfterDelete: '10s'
      scaleDownDelayAfterFailure: '3m'
      scaleDownUnneededTime: '10m'
      scaleDownUnreadyTime: '20m'
      scaleDownUtilizationThreshold: '0.5'
      scanInterval: '10s'
      skipNodesWithLocalStorage: 'false'
      skipNodesWithSystemPods: 'true'
    }
    disableLocalAccounts: true
    enableRBAC: true
    sku: {
      name: 'Base'
      tier: 'Standard'
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

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'vnet-${clusterName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.10.0.0/20'
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
    ]
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: 'acr${replace(clusterName, '-', '')}'
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Allow'
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource roleAssignmentAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, containerRegistry.id, 'AcrPull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: aksCluster.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

output controlPlaneFQDN string = aksCluster.properties.fqdn
output clusterName string = aksCluster.name
output kubeletIdentityObjectId string = aksCluster.identityProfile.kubeletidentity.objectId