@description('The Azure region where all resources will be deployed.')
param location string = resourceGroup().location

@description('The name of the Virtual Network.')
param vnetName string = 'vnet-prod-001'

@description('The address space for the Virtual Network.')
param vnetAddressPrefix string = '10.0.0.0/16