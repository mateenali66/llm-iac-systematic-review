param location string = resourceGroup().location
param aksName string
param dnsPrefix string = take(format('{0}-{1}', aksName, uniqueString(resourceGroup().id)), 54)
param aadAdminGroupObjectId string
param adminUsername string = 'aksadmin'
@secure()
param sshRSAPublicKey string

param vnetName string = '${aksName}-vnet'
param vnetAddressPrefix string = '10.1.0.0/16'
param subnetName string = 'nodepool-subnet'
param subnetAddressPrefix string = '10.1.0.0/24'

param systemVmSize string = 'Standard_D4s_v5'
param systemNodeCount int = 3
param systemMinCount int = 3
param systemMaxCount int = 6

param userVmSize string = 'Standard_D4s_v5'
param userNodeCount int = 3
param userMinCount int = 3
param userMaxCount int = 10

param availabilityZones array = [
  '1'
  '2'
  '3'
]

param workspaceName string = '${aksName}-law'

param natGatewayIpCount int = 2
@minValue(4)
@maxValue(120)
param natGatewayIdleTimeout int = 4

param serviceCidr string = '10.0.0.0/16'
param dnsServiceIp string = '10.0.0.10'
param podCidr string = '10.244.0.0/16'

@allowed([
  true
  false
])
param enableKeyVaultSecretsProvider bool = true

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${vnetName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-AzureLoadBalancer-Inbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-VNet-Inbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          access: 'Deny'
          direction: 'Inbound'
          priority: 4096
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-VNet-Outbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 100
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'Allow-Internet-Outbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 110
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  sku: {
    name: 'PerGB2018'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-04-01' = {
  name: aksName
  location: location
  sku: {
    name: 'Base'
    tier: 'Paid'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: [
        aadAdminGroupObjectId
      ]
    }
    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshRSAPublicKey
          }
        ]
      }
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: 'system'
      enablePrivateClusterPublicFQDN: false
    }
    oidcIssuerProfile: {
      enabled: true
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    addonProfiles: union({
      azurepolicy: {
        enabled: true
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: law.id
        }
      }
    }, enableKeyVaultSecretsProvider ? {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    } : {})
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      podCidr: podCidr
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIp
      outboundType: 'managedNATGateway'
      natGatewayProfile: {
        managedOutboundIPProfile: {
          count: natGatewayIpCount
        }
        idleTimeoutInMinutes: natGatewayIdleTimeout
      }
    }
    autoScalerProfile: {
      balanceSimilarNodeGroups: 'true'
      expander: 'least-waste'
      maxNodeProvisionTime: '15m'
      maxGracefulTerminationSec: '600'
      scaleDownDelayAfterAdd: '30m'
      scaleDownUnneededTime: '10m'
      scanInterval: '30s'
      skipNodesWithLocalStorage: 'false'
      skipNodesWithSystemPods: 'false'
    }
    agentPoolProfiles: [
      {
        name: 'systemnp'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        count: systemNodeCount
        minCount: systemMinCount
        maxCount: systemMaxCount
        enableAutoScaling: true
        vmSize: systemVmSize
        osType: 'Linux'
        osSKU: 'Ubuntu'
        osDiskSizeGB: 128
        kubeletConfig: {
          cpuCfsQuota: true
          cpuCfsQuotaPeriod: '100ms'
          containerLogMaxSizeMB: 100
          containerLogMaxFiles: 5
          failSwapOn: true
          podMaxPids: 4096
        }
        maxPods: 110
        vnetSubnetID: vnet::subnets[0].id
        enableNodePublicIP: false
        nodeLabels: {
          'kubernetes.azure.com/mode': 'system'
        }
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        availabilityZones: availabilityZones
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
  }
  tags: {
    environment: 'prod'
    workload: 'microservices'
  }
}

resource usernp 'Microsoft.ContainerService/managedClusters/agentPools@2024-04-01' = {
  name: '${aks.name}/usernp1'
  properties: {
    mode: 'User'
    type: 'VirtualMachineScaleSets'
    count: userNodeCount
    minCount: userMinCount
    maxCount: userMaxCount
    enableAutoScaling: true
    vmSize: userVmSize
    osType: 'Linux'
    osSKU: 'Ubuntu'
    osDiskSizeGB: 128
    kubeletConfig: {
      cpuCfsQuota: true
      cpuCfsQuotaPeriod: '100ms'
      containerLogMaxSizeMB: 100
      containerLogMaxFiles: 5
      failSwapOn: true
      podMaxPids: 4096
    }
    maxPods: 110
    vnetSubnetID: vnet::subnets[0].id
    enableNodePublicIP: false
    nodeLabels: {
      workload: 'general'
    }
    nodeTaints: []
    availabilityZones: availabilityZones
    upgradeSettings: {
      maxSurge: '33%'
    }
  }
  dependsOn: [
    aks
  ]
}