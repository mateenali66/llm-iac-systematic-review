@description('The name of the existing Azure Kubernetes Service (AKS) cluster to monitor.')
param aksClusterName string

@description('The name of the resource group where the existing AKS cluster is located.')
param aksClusterResourceGroupName string

@description('The name for the new Log Analytics workspace.')
param logAnalyticsWorkspaceName string = 'la-${uniqueString(resourceGroup().id)}'

@description('The name for the new Azure Monitor action group.')
param actionGroupName string = 'ag-aks-cpu-oncall'

@description('The name for the new metric alert rule.')
param alertRuleName string = 'ma-aks-high-cpu'

@description('The email address for the on-call engineer to receive alerts.')
param onCallReceiverEmail string

@description('The CPU usage percentage threshold for triggering the alert.')
@minValue(1)
@maxValue(100)
param cpuThresholdPercentage int = 80

@description('The location for the resources. Defaults to the resource group location.')
param location string = resourceGroup().location

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: 'aksoncall'
    enabled: true
    emailReceivers: [
      {
        name: 'OnCallEmail'
        emailAddress: onCallReceiverEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-08-01' existing = {
  name: aksClusterName
  scope: resourceGroup(aksClusterResourceGroupName)
}

resource cpuMetricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertRuleName
  location: '