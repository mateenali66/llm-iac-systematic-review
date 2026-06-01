@description('The resource ID of the Azure Kubernetes Service (AKS) cluster to monitor.')
param aksClusterResourceId string

@description('The name of the Log Analytics workspace.')
param workspaceName string = 'la-${uniqueString(resourceGroup().id)}'

@description('The location for the Log Analytics workspace. Defaults to the resource group location.')
param location string = resource