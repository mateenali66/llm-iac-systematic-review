@description('The location to deploy the resources.')
param location string = resourceGroup().location

@description('The name of the Virtual Network.')
param vnetName string = 'vnet-prod-eus-001'

@description('The name of the Network Security Group.')
param nsgName string = 'nsg-webtier-001