targetScope = 'subscription'

@description('The object ID of the Azure AD security group to which the role will be assigned.')
param principalId string

@description('The display name for the custom role.')
param roleName string = 'Virtual Machine Reader (Custom)'

@description('A detailed description for the custom role.')
param roleDescription string = 'Provides read-only access to virtual machines and their related networking and storage components.'

var roleDefinitionName = guid(subscription().id, roleName)

resource customRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionName
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'Custom