@description('The globally unique name of the Azure Key Vault.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('The Azure location for the resources.')
param location string = resourceGroup().location

@description('The object ID of a user, group, or service principal that will be granted Secret User access to the Key Vault.')
param principalId string

@description('The resource ID of the virtual network where the private endpoint for the Key Vault will be created.')
param vnetId string

@description('The resource ID of the subnet where the private endpoint for the Key Vault will be created.')
param subnetId string

@description('Tags to apply to the resources.')
param tags object = {}

var privateDnsZoneName = 'privatelink.vaultcore.azure.net'
var keyVaultSecretsUserRoleDefinitionId = '/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86