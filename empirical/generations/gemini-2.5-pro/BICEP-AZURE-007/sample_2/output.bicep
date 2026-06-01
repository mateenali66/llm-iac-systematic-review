@description('The location for all resources.')
param location string = resourceGroup().location

@description('The base name for the AKS cluster and related resources.')
param clusterName string = 'aksprod${uniqueString(resourceGroup().id)}'

@description('The DNS prefix for the AKS cluster.')
param dnsPrefix string = clusterName

@description('The version of Kubernetes to use for the AKS cluster.')
param kubernetesVersion string = '1.29.2'

@description('The administrator username for the cluster nodes.')
@minLength(1)
param adminUsername string = 'azureuser'

@description('The SSH public key for accessing the cluster nodes.')
@secure()
param sshPublicKey string

@description('The VM size for the system node pool.')
param systemNodePoolVmSize string = 'Standard_DS2_v2'

@description('The initial node count for the system node pool.')
@minValue(3)
@maxValue(100)
param systemNodePoolNodeCount int = 3

@description('The minimum node count for the system node pool autoscaler.')
@minValue(3)
@maxValue(100)
param systemNodePoolMinCount int = 3

@description('The maximum node count for the system node pool autoscaler.')
@minValue(3)
@maxValue(100)
param systemNodePoolMaxCount int = 5

@description('The VM size for the user node pool.')
param userNodePoolVmSize string = 'Standard_D4s_v3'

@description('The initial node count for the user node pool.')
@minValue(1)
@maxValue(100)
param userNodePoolNodeCount int = 2

@description('The minimum node count for the user node pool autoscaler.')
@minValue(1)
@maxValue(100)
param userNodePoolMinCount int = 2

@description('The maximum node count for the user node pool autoscaler.')
@minValue(1)
@maxValue(100)
param userNodePoolMaxCount int = 10

@description('The virtual network address prefix.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('The subnet address prefix for the AKS nodes.')
param aksSubnetPrefix string = '10.0.1.0/24'

@description('The service CIDR for the AKS cluster.')
param serviceCidr string = '10.1.0.0/16'

@description('The DNS service IP for the AKS cluster.')
param dnsServiceIP string = '10.1.0.10'

@description('The Docker bridge CIDR for the AKS cluster.')
param dockerBridgeCidr string = '172.17.0.1/16'

@description('Array of AAD group object IDs that will have admin rights on the cluster.')
param adminGroupObjectIDs array = []

@description('IP ranges authorized to access the Kubernetes API server. Set to an empty array to allow all, but not recommended for production.')
param authorizedIPRanges array = []

var logAnalyticsWorkspaceName = '${clusterName}-logs'
var virtualNetworkName = '${clusterName}-vnet'
var aksSubnetName = 'aks-subnet'
var clusterIdentityName = '${clusterName}-identity'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: virtualNetworkName
  location: location
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

resource clusterIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: clusterIdentityName
  location: location
}

resource clusterIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(virtualNetwork.id, clusterIdentity.id, 'Network Contributor')
  scope: virtualNetwork
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization