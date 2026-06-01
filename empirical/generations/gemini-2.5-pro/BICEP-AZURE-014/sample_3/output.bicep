targetScope = 'subscription'

@description('The object ID of the security group to which the role will be assigned.')
param principalId string

@description('The name of the resource group where the role assignment will be created.')
param assignmentResourceGroupName string

@description('The display name for the custom role.')
param customRoleName string = 'Virtual Machine Read-Only Access