@description('The location for all resources.')
param location string = resourceGroup().location

@description('A prefix for all resource names.')
param prefix string

@description('The administrator username for the virtual machines.')
param adminUsername string

@description('The SSH public key for the administrator account.')
@secure()
param adminSshPublicKey string

@description('Base6