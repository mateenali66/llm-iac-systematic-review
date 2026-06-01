@description('Name of the AKS cluster')
param clusterName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = clusterName

@description('Kubernetes version')
param kubernetesVersion string = '1.29.2'

@description('System node pool VM size')
param systemNodeVmSize string = 'Standard_D4s_v5'

@description('System node pool minimum node count')
@minValue(1)
param systemNodeMinCount int = 3

@description('System node pool maximum node count')
@minValue(1)
param systemNodeMaxCount int = 5

@description('User node pool VM size')
param userNodeVmSize string = 'Standard_D8s_v5'

@description('User node pool minimum node count')
@minValue(1)
param userNodeMinCount int = 3

@description('User node pool maximum node count')
@minValue(1)
param userNodeMaxCount int = 20

@description('Availability zones for node pools')
param availabilityZones array = [
  '1'
  '2'
  '3'
]

@description('Log Analytics workspace retention in days')
@minValue(30)
@maxValue(730)
param logRetentionInDays int = 90

@description('Authorized IP ranges allowed to access the API server')
param apiServerAuthorizedIpRanges array = []

@description('Object ID of the Entra ID group with cluster admin rights')
param adminGroupObjectIds array

@description('Tags applied to all resources')
param tags object = {
  environment: 'production'
  workload: 'microservices'
  managedBy: 'bicep'
}

var logAnalyticsName = '${clusterName}-law'
var vnetName = '${clusterName}-vnet'
var subnetName = 'aks-subnet'
var nodeResourceGroupName = '${resourceGroup().name}-nodes'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.240.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.240.0.0/20'
          privateEndpointNetworkPolicies: 'Disabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
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

var networkContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')

resource aksSubnetRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet.id, aksIdentity.id, networkContributorRoleId)
  scope: vnet
  properties: {
    roleDefinitionId: networkContributorRoleId
    principalId: aksIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
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
    nodeResourceGroup: nodeResourceGroupName
    enableRBAC: true
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: adminGroupObjectIds
      tenantID: subscription().tenantId
    }
    apiServerAccessProfile: {
      authorizedIPRanges: apiServerAuthorizedIpRanges
      enablePrivateCluster: false
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'cilium'
      networkDataplane: 'cilium'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        vmSize: systemNodeVmSize
        count: systemNodeMinCount
        minCount: systemNodeMinCount
        maxCount: systemNodeMaxCount
        enableAutoScaling: true
        availabilityZones: availabilityZones
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: '${vnet.id}/