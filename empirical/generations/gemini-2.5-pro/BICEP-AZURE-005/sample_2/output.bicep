@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The base name for the resources. A unique string will be appended to the SQL Server name.')
param baseName string = 'prodecom'

@description('The administrator username for the new SQL logical server.')
@minLength(1)
param administratorLogin string