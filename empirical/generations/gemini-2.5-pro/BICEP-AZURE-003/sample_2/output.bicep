@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('A prefix for the Web App name. The final name will be generated to be globally unique.')
param appNamePrefix string = 'webapp-node'

@description('The name of the App Service Plan.')
param appServicePlanName string = 'asp-node-prod'

@description('The SKU for the App Service Plan.')
param appServicePlanSku object =