@description('The location to deploy the resources.')
param location string = resourceGroup().location

@description('The base name for resources.')
param baseName string = 'prod-app'

@description('The administrator username for the virtual machines.')
param adminUsername string

@description('The administrator password for the virtual machines.')
@secure()
param adminPassword string

@description('The size of the virtual machines.')
param vmSize string = 'Standard_DS2_v2'

@description('The image for the virtual machines.')
param vmImageReference object = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

var vnetName = '${baseName}-vnet'
var appGatewaySubnetName = 'agw-subnet'
var vmSubnetName = 'vm-subnet'
var publicIpName = '${baseName}-pip'
var appGatewayName = '${baseName}-agw'
var wafPolicyName = '${baseName}-waf'
var nsgName = '${baseName}-nsg'
var vm1Name = '${baseName}-vm1'
var vm2Name = '${baseName}-vm