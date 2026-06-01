@description('The Azure region where all resources will be deployed.')
param location string = resourceGroup().location

@description('The base name for the network resources.')
param baseName string = 'prod'

@description('The address space for the Virtual Network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('The address prefix for the web subnet.')
param webSubnetPrefix string = '10.0.1.0/24'

@description('The address prefix for the application subnet.')
param appSubnetPrefix string = '10.0.2.0/24'

@description('The address prefix for the data subnet.')
param dataSubnetPrefix string = '10.0.3.0/24'

@description('The address prefix for the Azure Bastion subnet. Must be /26 or larger.')
param bastionSubnetPrefix string = '10.0.0.0/26'

var vnetName = 'vnet-${baseName}'
var nsgName = 'nsg-${baseName}-tiers'
var webSubnetName = 'snet-web'
var appSubnetName = 'snet-app'