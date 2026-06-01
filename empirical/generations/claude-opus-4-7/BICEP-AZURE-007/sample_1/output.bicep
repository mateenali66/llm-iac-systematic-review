@description('The name of the AKS cluster.')
@minLength(3)
@maxLength(63)
param clusterName string

@description('The location for all resources.')
param location string = resourceGroup().location

@description('The DNS prefix for the AKS cluster.')
param dnsPrefix string = '${clusterName}-dns'

@description('The Kubernetes version.')
param kubernetesVersion string = '1.29.2'

@description('The Azure AD admin group object IDs for cluster admin access.')
param adminGroupObjectIDs array

@description('System node pool VM size.')
param systemNodeVmSize string = 'Standard_D4s_v5'

@description('User node pool VM size.')
param userNodeVmSize string = 'Standard_D8s_v5'

@description('Minimum number of nodes in the system pool.')
@minValue(1)
param systemNodeMinCount int = 3

@description('Maximum number of nodes in the system pool.')
param systemNodeMaxCount int = 5

@description('Minimum number of nodes in the user pool.')
@minValue(1)
param userNodeMinCount int = 3

@description('Maximum number of nodes in the user pool.')
param userNodeMaxCount int = 20

@description('Resource ID of the Log Analytics workspace for monitoring.')
param logAnalyticsWorkspaceId string

@description('Resource ID of the subnet for AKS nodes.')
param subnetId string

@description('Tags to apply to all resources.')
param tags object = {
  environment: 'production'
  workload: 'microservices'
  managedBy: 'bicep'
}

@description('Network plugin to use.')
@allowed([
  'azure'
  'kubenet'
])
param networkPlugin string = 'azure'

@description('Service CIDR for Kubernetes services.')
param serviceCidr string = '10.100.0.0/16'

@description('DNS service IP within the service CIDR.')
param dnsServiceIP string = '10.100.0.10'

resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    enableRBAC: true
    disableLocalAccounts: true
    nodeResourceGroup: 'MC_${resourceGroup().name}_${clusterName}'
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: adminGroupObjectIDs
      tenantID: subscription().tenantId
    }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        vmSize: systemNodeVmSize
        count: systemNodeMinCount
        minCount: systemNodeMinCount
        maxCount: systemNodeMaxCount
        enableAutoScaling: true
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetId
        maxPods: 50
        orchestratorVersion: kubernetesVersion
        enableEncryptionAtHost: true
        enableNodePublicIP: false
        upgradeSettings: {
          maxSurge: '33%'
        }
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        tags: tags
      }
      {
        name: 'user'
        mode: 'User'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        vmSize: userNodeVmSize
        count: userNodeMinCount
        minCount: userNodeMinCount
        maxCount: userNodeMaxCount
        enableAutoScaling: true
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetId
        maxPods: 100
        orchestratorVersion: kubernetesVersion
        enableEncryptionAtHost: true
        enableNodePublicIP: false
        upgradeSettings: {
          maxSurge: '33%'
        }
        tags: tags
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: 'calico'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
      enablePrivateClusterPublicFQDN: false
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
      azurepolicy: {
        enabled: true
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      defender: {
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
        securityMonitoring: {
          enabled: true
        }
      }
      im