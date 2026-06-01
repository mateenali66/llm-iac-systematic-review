targetScope = 'resourceGroup'

@description('The location for all resources in this deployment.')
param location string = resourceGroup().location

@description('A prefix for the storage account name. A unique string will be appended to this prefix.')
@minLength(3)
@maxLength(11)
param storageAccountNamePrefix string = 'st'

@description('