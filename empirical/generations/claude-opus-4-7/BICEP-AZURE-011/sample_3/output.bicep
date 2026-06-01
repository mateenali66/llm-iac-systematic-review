@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name used for tagging and naming')
param environment string = 'prod'

@description('Base name prefix for resources')
@minLength(2)
@maxLength(10)
param namePrefix string = 'appgw'

@description('Admin username for the backend VMs')
param adminUsername string

@description('SSH public key for the backend VMs')
@secure()
param adminSshPublicKey string

@description('VM size for the backend pool VMs')
param vmSize string = 'Standard_D2s_v5'

@description('Address space for the virtual network')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('Subnet prefix for Application Gateway (must be /24 or larger)')
param appGwSubnetPrefix string = '10.20.1.0/24'

@description('Subnet prefix for backend VMs')
param backendSubnetPrefix string = '10.20.2.0/24'

@description('Allowed source IP ranges for management access to VMs (SSH)')
param allowedManagementCidrs array = []

@description('WAF mode (Detection or Prevention)')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

@description('Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

var tags = {
  environment: environment
  workload: namePrefix
  managedBy: 'bicep'
}

var vnetName = '${namePrefix}-vnet-${environment}'
var appGwSubnetName = 'appgw-subnet'
var backendSubnetName = 'backend-subnet'
var appGwName = '${namePrefix}-agw-${environment}'
var pipName = '${namePrefix}-pip-${environment}'
var wafPolicyName = '${namePrefix}-wafpol-${environment}'
var nsgBackendName = '${namePrefix}-nsg-backend-${environment}'
var vmNames = [
  '${namePrefix}-vm-01'
  '${namePrefix}-vm-02'
]

resource nsgBackend 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgBackendName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-AppGw-HTTP-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: appGwSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: backendSubnetPrefix
          destinationPortRange: '80'
        }
      }
      {
        name: 'Allow-Management-SSH-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: empty(allowedManagementCidrs) ? 'Deny' : 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefixes: allowedManagementCidrs
          sourceAddressPrefix: empty(allowedManagementCidrs) ? '*' : null
          sourcePortRange: '*'
          destinationAddressPrefix: backendSubnetPrefix
          destinationPortRange: '22'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: appGwSubnetName
        properties: {
          addressPrefix: appGwSubnetPrefix
        }
      }
      {
        name: backendSubnetName
        properties: {
          addressPrefix: backendSubnetPrefix
          networkSecurityGroup: {
            id: nsgBackend.id
          }
        }
      }
    ]
  }
}

resource appGwPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-09-01' = {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    policySettings: {
      state: 'Enabled'
      mode: wafMode
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
  }
}

resource vmNics 'Microsoft.Network/networkInterfaces@2023-09-01' = [for (vmName, i) in vmNames: {