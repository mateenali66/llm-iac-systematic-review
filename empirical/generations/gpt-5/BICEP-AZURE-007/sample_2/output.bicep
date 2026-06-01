param location string = resourceGroup().location

@minLength(1)
param aksName string

@description('Specify the Kubernetes version, or leave empty for default.')
param kubernetesVersion string = ''

@description('Enable Azure RBAC for Kubernetes.')
param enableAzureRBAC bool = true

@description('Admin AAD group object IDs for cluster admin access.')
param adminGroupObjectIds array = []

@description('VNet name for AKS nodes and pods.')
param vnetName string = 'prod-aks-vnet'

@description('Address space for the VNet.')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Subnet name for AKS.')
param aksSubnetName string = 'aks-subnet'

@description('Subnet address prefix for AKS.')
param aksSubnetPrefix string = '10.10.0.0/18'

@description('Service CIDR for Kubernetes services.')
param serviceCidr string = '10.0.0.0/16'

@description('DNS service IP within the service CIDR.')
param dnsServiceIP string = '10.0.0.10'

@description('Docker bridge CIDR.')
param dockerBridgeCidr string = '172.17.0.1/16'

@description('Log Analytics workspace name for monitoring.')
param logAnalyticsWorkspaceName string = 'law-aks-${uniqueString(resourceGroup().id)}'

@description('System node pool VM size.')
param systemVMSize string = 'Standard_D4as_v5'

@description('User node pool VM size.')
param userVMSize string = 'Standard_D8as_v5'

@description('Initial node count for the system node pool.')
@minValue(1)
param systemNodeCount int = 3

@description('Initial node count for the user node pool.')
@minValue(1)
param userNodeCount int = 3

@description('Autoscaler minimum nodes for system pool.')
@minValue(1)
param systemPoolMinCount int = 3

@description('Autoscaler maximum nodes for system pool.')
@minValue(1)
param systemPoolMaxCount int = 10

@description('Autoscaler minimum nodes for user pool.')
@minValue(1)
param userPoolMinCount int = 3

@description('Autoscaler maximum nodes for user pool.')
@minValue(1)
param userPoolMaxCount int = 20

@description('Enable encryption at host on node pools.')
param encryptionAtHost bool = true

@description('Resource tags.')
param tags object = {
  environment: 'prod'
  workload: 'microservices'
}

var aksSubnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, aksSubnetName)

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  sku: {
    name: 'PerGB2018'
  }
  retentionInDays: 30
  publicNetworkAccessForIngestion: 'Enabled'
  publicNetworkAccessForQuery: 'Enabled'
  tags: tags
}

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
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
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
    kubernetesVersion: kubernetesVersion != '' ? kubernetesVersion : null
    dnsPrefix: toLower('${substring(aksName, 0, 30)}-${uniqueString(resourceGroup().id)}')
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: enableAzureRBAC
      adminGroupObjectIDs: adminGroupObjectIds
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: 'System'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    workloadIdentityProfile: {
      enabled: true
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    addonProfiles: {
      azurepolicy: {
        enabled: true
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalytics.id
        }
      }
    }
    agentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        vmSize: systemVMSize
        osType: 'Linux'
        osDiskType: 'Managed'
        osDiskSizeGB: 128
        count: systemNodeCount
        enableAutoScaling: true
        minCount: systemPoolMinCount
        maxCount: systemPoolMaxCount
        vnetSubnetID: aksSubnetId
        maxPods: 50
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '33%'
        }
        enableNodePublicIP: false
        scaleSetPriority: 'Regular'
        enableEncryptionAtHost: encryptionAtHost
        orchestratorVersion: kubernetesVersion != '' ? kubernetesVersion : null
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      dockerBridgeCidr: dockerBridgeCidr
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 2
        }
        allocatedOutboundPorts: 0
        idleTimeoutInMinutes: 30
      }
    }
    disableLocalAccounts: true
    securityProfile: {
      imageCleaner: {
        enabled: true
        intervalHours: 48
      }
    }
  }
}

resource userpool 'Microsoft.ContainerService/managedClusters/agentPools@2024-02-01' = {
  name: '${aks.name}/userpool'
  properties: {
    mode: 'User'
    type: 'VirtualMachineScaleSets'
    vmSize: userVMSize
    osType: 'Linux'
    osDiskType: 'Managed'
    osDiskSizeGB: 128
    count: userNodeCount
    enableAutoScaling: true
    minCount: userPoolMinCount
    maxCount: userPoolMaxCount
    vnetSubnetID: aksSubnetId
    maxPods: 50
    availabilityZones: [
      '1'
      '2'
      '3'
    ]
    upgradeSettings: {
      maxSurge: '50%'
    }
    enableNodePublicIP: false
    scaleSetPriority: 'Regular'
    enableEncryptionAtHost: encryptionAtHost
    orchestratorVersion: kubernetesVersion != '' ? kubernetesVersion : null
    nodeLabels: {
      workload: 'general'
    }
    nodeTaints: []
  }
  dependsOn: [
    aks
  ]
}

resource aksSubnetExisting 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  name: '${vnet.name}/${aksSubnetName}'
}

resource subnetRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksSubnetExisting.id, 'b24988ac-6180-42a0-ab88-20f7382dd24c', aks.identity.principalId)
  scope: aksSubnetExisting
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Network Contributor
    principalId: aks.identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    aks
  ]
}

output aksClusterName string = aks.name
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
output kubeletIdentityClientId string = aks.properties.identityProfile.kubeletidentity.clientId
output kubeletIdentityObjectId string = aks.properties.identityProfile.kubeletidentity.objectId
output logAnalyticsWorkspaceId string = logAnalytics.id
output vnetId string = vnet.id
output aksSubnetIdOut string = aksSubnetId