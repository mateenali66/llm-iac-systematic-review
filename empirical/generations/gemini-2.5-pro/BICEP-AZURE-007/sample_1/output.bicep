targetScope = 'resourceGroup'

@description('Prefix for all resource names.')
@minLength(3)
@maxLength(10)
param prefix string

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The object IDs of the Azure AD groups that will have admin access to the cluster.')