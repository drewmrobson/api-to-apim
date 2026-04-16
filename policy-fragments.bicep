///
// Deploy XML Policy Fragments to Azure API Management
///

@description('Existing target API Management instance')
param apiManagementName string

@description('List of policy fragments for this resource.')
param policyFragments array

// Existing API Management Service
resource existingApiManagement 'Microsoft.ApiManagement/service@2024-10-01-preview' existing = {
  name: apiManagementName
}

resource policyFragmentsResource 'Microsoft.ApiManagement/service/policyFragments@2024-10-01-preview' = [
  for fragment in policyFragments: {
    name: fragment.id
    parent: existingApiManagement
    properties: {
      description: 'No description'
      format: fragment.format
      value: fragment.value
    }
  }
]
