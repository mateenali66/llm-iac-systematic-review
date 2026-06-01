@description('The name of the AKS cluster')
param clusterName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('Kubernetes version')
param kubernetesVersion string = '1.29.2'

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = '${clusterName}-dns'

@description('Environment tag')
param environment string = 'production'

@description('System node pool VM size')
param systemNodeVmSize string = 'Standard_D4س_v5'

@description('User node pool VM size')
param userNodeVmSize string = 'Standard_D8s_v5'

@description('System node pool min count')
@minValue(1)
param systemNodeMinCount int = 3

@description('System node pool max count')
param systemNodeMaxCount int = 5

@description('User node pool min count')
@minValue(1)
param userNodeMinCount int = 3

@description('User node pool max count')
param userNodeMaxCount int = 20

@description('Authorized IP ranges for API server access')
param authorizedIpRanges array = []

@description('Log Analytics workspace retention in days')
param logRetentionDays int = 30

@description('Admin group object IDs for cluster admin RBAC')
param adminGroupObjectIds array = []

@description('Tenant ID for Azure AD integration')
param tenantId string = subscription().tenantId

var tags = {
  environment: environment
  workload: 'microservices'
  managedBy: 'bicep'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${clusterName}-law'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${clusterName}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.0.0.0/20'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${clusterName}-identity'
  location: location
  tags: tags
}

resource networkContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet.id, aksIdentity.id, 'NetworkContributor')
  scope: vnet
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
    principalId: aksIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    enableRBAC: true
    disableLocalAccounts: true
    nodeResourceGroup: '${resourceGroup().name}-nodes'
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: systemNodeMinCount
        minCount: systemNodeMinCount
        maxCount: systemNodeMaxCount
        enableAutoScaling: true
        vmSize: systemNodeVmSize
        osType: 'Linux'
        osSKU: 'AzureLinux'
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        maxPods: 50
        vnetSubnetID: '${vnet.id}/subnets/aks-subnet'
        upgradeSettings: {
          maxSurge: '33%'
        }
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        tags: tags
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'cilium'
      networkDataplane: 'cilium'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
      podCidr: '10.244.0.0/16'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: adminGroupObjectIds
      tenantID: tenantId
    }
    apiServerAccessProfile: {
      authorizedIPRanges: authorizedIpRanges
      enablePrivateCluster: false
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalytics