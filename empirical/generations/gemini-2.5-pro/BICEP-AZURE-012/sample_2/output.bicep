@description('The prefix for all resource names.')
@minLength(3)
@maxLength(12)
param appNamePrefix string = 'fncapp${uniqueString(resourceGroup().id)}'

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The runtime stack for