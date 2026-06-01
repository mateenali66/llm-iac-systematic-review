param location string = resourceGroup().location
param aksName string
param kubernetesVersion string = ''
param aadAdminGroupObjectIds array

param vnetName string = '${aksName}-vnet'
param vnetAddressPrefix string = '10.2.0.0/16'
param aksSubnetName string = 'aks-subnet'
param aksSubnetPrefix string = '10.2.0.0/24'

param enablePrivateCluster bool = true
param authorizedIPRanges array = []

param logAnalyticsWorkspaceName string = '${aksName}-law'
param logAnalyticsRetentionDays int = 30

param systemNodeVMSize string = 'Standard_D4s_v5'
param userNodeVMSize string = 'Standard_D4s_v5'
param systemMinCount int = 3
param systemMaxCount int = 6
param userMinCount int = 3
param userMaxCount int = 10
param systemOsDiskSizeGB int = 128
param userOsDiskSizeGB int = 128
param zones array = [
  '1'
  '2'
  '3'
]

param podCidr string = '10.244.0.0/16'
param serviceCidr string = '10.0.0.0/16'
param dnsServiceIP string = '10.0.0.10'
param outboundIpCount int = 2

param enableEncryptionAtHost bool = false

param nodeResourceGroupName string = 'MC_${resourceGroup().name}_${aksName}_${location}'

param tags object = {
  environment: 'prod'
  workload: 'microservices'
}

var subnetId = '${resourceId('Microsoft.Network/virtualNetworks', vnetName)}/subnets/${aksSubnetName}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: aksSubnetName
        properties: {
          addressPrefix: aksSubnetPrefix
        }
      }
    ]
  }
}

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logAnalyticsRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-05-01' = {
  name: aksName
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Paid'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion == '' ? null : kubernetesVersion
    dnsPrefix: toLower('${aksName}-dns')
    nodeResourceGroup: nodeResourceGroupName
    enableRBAC: true
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: aadAdminGroupObjectIds
    }
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
      enablePrivateClusterPublicFQDN: false
      privateDNSZone: enablePrivateCluster ? 'System' : null
      authorizedIPRanges: enablePrivateCluster ? null : authorizedIPRanges
    }
    autoScalerProfile: {
      balanceSimilarNodeGroups: 'true'
      expander: 'least-waste'
      maxEmptyBulkDelete: '10'
      maxGracefulTerminationSec: '600'
      maxTotalUnreadyPercentage: '45'
      okTotalUnreadyCount: '3'
      scanInterval: '20s'
      scaleDownDelayAfterAdd: '15m'
      scaleDownDelayAfterDelete: '15s'
      scaleDownDelayAfterFailure: '10m'
      scaleDownUnneededTime: '10m'
      scaleDownUnreadyTime: '20m'
      scaleDownUtilizationThreshold: '0.5'
      skipNodesWithLocalStorage: 'false'
      skipNodesWithSystemPods: 'false'
      newPodScaleUpDelay: '0s'
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      imageCleaner: {
        enabled: true
        intervalHours: 48
      }
    }
    addonProfiles: {
      azurepolicy: {
        enabled: true
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: law.id
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      podCidrs: [
        podCidr
      ]
      loadBalancerSku: 'standard'
      outboundType: 'managedNATGateway'
      natGatewayProfile: {
        managedOutboundIPProfile: {
          count: outboundIpCount
        }
      }
      ipFamilies: [
        'IPv4'
      ]
      vnetSubnetID: subnetId
    }
    agentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
        count: systemMinCount
        enableAutoScaling: true
        minCount: systemMinCount
        maxCount: systemMaxCount
        vmSize: systemNodeVMSize
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        osDiskType: 'Managed'
        osDiskSizeGB: systemOsDiskSizeGB
        availabilityZones: zones
        enableNodePublicIP: false
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        nodeLabels: {
          'nodepool-type': 'system'
          'workload': 'system'
        }
        scaleSetPriority: 'Regular'
        upgradeSettings: {
          maxSurge: '33%'
        }
        enableEncryptionAtHost: enableEncryptionAtHost
        orchestratorVersion: kubernetesVersion == '' ? null : kubernetesVersion
      }
    ]
  }
}

resource userpool 'Microsoft.ContainerService/managedClusters/agentPools@2024-05-01' = {
  name: '${aks.name}/userpool'
  properties: {
    mode: 'User'
    count: userMinCount
    enableAutoScaling: true
    minCount: userMinCount
    maxCount: userMaxCount
    vmSize: userNodeVMSize
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
    osDiskType: 'Managed'
    osDiskSizeGB: userOsDiskSizeGB
    availabilityZones: zones
    enableNodePublicIP: false
    nodeLabels: {
      'nodepool-type': 'user'
      'workload': 'general'
    }
    upgradeSettings: {
      maxSurge: '50%'
    }
    enableEncryptionAtHost: enableEncryptionAtHost
    orchestratorVersion: kubernetesVersion == '' ? null : kubernetesVersion
  }
  dependsOn: [
    aks
  ]
}

resource aksDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'aksDiagnostics'
  scope: aks
  properties: {
    workspaceId: law.id
    logs: [
      {
        category: 'kube-audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'kube-audit-admin'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'kube-apiserver'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'kube-controller-manager'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'kube-scheduler'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'cluster-autoscaler'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'cloud-controller-manager'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'guard'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}