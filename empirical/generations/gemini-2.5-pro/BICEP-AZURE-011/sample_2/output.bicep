@secure()
@description('Password for the Virtual Machines.')
param adminPassword string

@description('Username for the Virtual Machines.')
param adminUsername string = 'azureuser'

@description('A prefix used to generate unique resource names.')
param namePrefix string = 'appgw-demo'

@description('The Azure region where the resources will be deployed.')
param location string