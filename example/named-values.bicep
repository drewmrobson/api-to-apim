///
// Deploy Named Values to Azure API Management
///

@description('Name of the existing API Management service.')
param apiManagementName string

@description('Name of the Azure Key Vault to source secret named values from.')
param keyVaultName string

@description('Named values to create.')
param namedValues array

@description('Secret named values to create, with values sourced from Azure Key Vault.')
param secretNamedValues array

resource existingApiManagement 'Microsoft.ApiManagement/service@2024-10-01-preview' existing = {
  name: apiManagementName
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Key Vault Secrets User built-in role; allows APIM to read secret values.
resource apimKeyVaultSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingKeyVault.id, existingApiManagement.id, 'KeyVaultSecretsUser')
  scope: existingKeyVault
  properties: {
    principalId: existingApiManagement.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}

resource namedValue 'Microsoft.ApiManagement/service/namedValues@2024-10-01-preview' = [
  for nv in namedValues: {
    name: nv.key
    parent: existingApiManagement
    properties: {
      displayName: nv.key
      value: nv.value
    }
  }
]

resource secretNamedValuesResource 'Microsoft.ApiManagement/service/namedValues@2024-10-01-preview' = [
  for nv in secretNamedValues: {
    name: nv.key
    parent: existingApiManagement
    dependsOn: [
      apimKeyVaultSecretsUserRoleAssignment
    ]
    properties: {
      secret: true
      displayName: nv.key
      keyVault: {
        secretIdentifier: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/${nv.key}'
      }
    }
  }
]
