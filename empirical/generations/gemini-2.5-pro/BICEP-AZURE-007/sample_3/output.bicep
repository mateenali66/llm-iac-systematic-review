@description('The location for the Azure Kubernetes Service (AKS) cluster and related resources.')
param location string = resourceGroup().location

@description('A prefix for all resource names to ensure uniqueness.')
param namePrefix string = 'prod'

@description('The Azure Active Directory group object ID for Kubernetes administrators.')
@secure()
param adminGroupObjectID string

@description('The resource ID of the subnet where the AKS nodes will be deployed. This subnet must be within a VNet.')
param nodeSubnetId string

@description('The version of Kubernetes to use for the cluster.')
param kubernetesVersion string = '1.28.5'

@description('The VM size for the system node pool.')
param systemNodePoolVmSize string = 'Standard_DS2_v2'

@description('The number of nodes in the system node pool.')
@minValue(3)
@maxValue(5)
param systemNodePoolNodeCount int = 3

@description('The VM size for the user