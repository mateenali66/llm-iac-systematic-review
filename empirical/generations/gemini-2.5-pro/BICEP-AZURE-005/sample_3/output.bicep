@description('The base name for all resources.')
@minLength(3)
@maxLength(12)
param projectName string

@description('The environment for the deployment (e.g., dev, tst, prod).')
@allowed([
  'dev'
  'tst'
  'prod'
])
param environment string = 'prod'

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The administrator username for the SQL server. This will be disabled if AAD-only auth is enabled, but is required for creation.')
param sqlAdminUsername string

@description('The administrator password for the SQL server. Must meet complexity requirements.')
@secure()
param sqlAdminPassword string

@description('The login name of the Azure AD administrator. Can be a user or group.')
param aadAdminLogin string

@description('The object ID of the Azure AD administrator.')
param aadAdminObjectId string

@description('The tenant ID of the Azure AD