targetScope = 'resourceGroup'

param location string = resourceGroup().location
param clusterName string = 'aks-cluster-${uniqueString(resourceGroup().id)}'
param dnsPrefix string = 'aks-dns-${uniqueString(resourceGroup().id)}'
param kubernetesVersion string = '1.27.3'
param systemNodePoolName string = 'systempool'
param userNodePoolName string = 'userpool'
param systemNodeCount int = 3
param userNodeCount int = 3
param systemVmSize string = 'Standard_D4s_v3'
param userVmSize string = 'Standard_D4s_v3'
param adminUsername string = 'azureuser'
param sshPublicKey string

var aksSubnetName = 'aks-subnet'
var networkContributorRole = '4d97b98b-1d4f-4787-a291-c67834d212e7'

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: 'aks-vnet-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: aksSubnetName
        properties: {
          addressPrefix: '10.0.0.0/20'
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
            {
              service: 'Microsoft.Storage'
            }
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: aksSubnetName
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'aks-log-analytics-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-05-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: systemNodePoolName
        count: systemNodeCount
        vmSize: systemVmSize
        osDiskSizeGB: 128
        osDiskType: 'Ephemeral'
        vnetSubnetID: aksSubnet.id
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        enableAutoScaling: false
        enableNodePublicIP: false
        enableFIPS: false
        kubeletDiskType: 'OS'
        maxPods: 30
        orchestratorVersion: kubernetesVersion
        osType: 'Linux'
        scaleDownMode: 'Delete'
        upgradeSettings: {
          maxSurge: '10%'
        }
      }
      {
        name: userNodePoolName
        count: userNodeCount
        vmSize: userVmSize
        osDiskSizeGB: 128
        osDiskType: 'Ephemeral'
        vnetSubnetID: aksSubnet.id
        mode: 'User'
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        enableAutoScaling: true
        minCount: 1
        maxCount: 10
        enableNodePublicIP: false
        enableFIPS: false
        kubeletDiskType: 'OS'
        maxPods: 30
        orchestratorVersion: kubernetesVersion
        osType: 'Linux'
        scaleDownMode: 'Delete'
        upgradeSettings: {
          maxSurge: '10%'
        }
      }
    ]
    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
      azurepolicy: {
        enabled: true
      }
      httpApplicationRouting: {
        enabled: false
      }
      ingressApplicationGateway: {
        enabled: false
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      serviceCidr: '10.2.0.0/16'
      dnsServiceIP: '10.2.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
      authorizedIPRanges: []
    }
    disableLocalAccounts: true
    enableRBAC: true
    sku: {
      name: 'Base'
      tier: 'Standard'
    }
  }
  dependsOn: [
    vnet
    logAnalyticsWorkspace
  ]
}

resource aksAcrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, 'acrPull')
  scope: aksCluster
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aksCluster.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output controlPlaneFQDN string = aksCluster.properties.fqdn
output kubeconfig object = {
  host: aksCluster.properties.fqdn
  caData: aksCluster.properties.certificateProfile.kubeConfigCertificateAuthorityData
}