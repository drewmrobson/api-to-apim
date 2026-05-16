///
// Bicep module to deploy Policy Fragments, Named Values and an API to Azure API Management
///

@description('Name of existing API Management to use.')
param apiManagementName string

@description('Name of the API Management Logger to use for this workload. This logger must already exist in the API Management instance specified by apiManagementName.')
param apiManagementLoggerName string

@description('Name of the Azure Key Vault to source secret named values from.')
param keyVaultName string

@description('Name of the API to create within API Management. Must be all lowercase with no special characters or spaces.')
param apiName string

@description('Display name of the API to create within API Management.')
param apiDisplayName string

@description('Version of the API to create within API Management.')
param apiVersion string

@description('URL suffix of the API to create within API Management.')
param apiUrlSuffix string

@secure()
@description('OpenAPI specification content as a string. This is used when the OpenAPI content is small enough to be passed as a string parameter. For larger OpenAPI specifications, use the openApiYamlContent parameter to pass the content as an object.')
param openApiTextContent string

@description('OpenAPI specification content as an object. This is used instead of the openApiTextContent parameter when the content is too large to be passed as a string.')
param openApiYamlContent object

@description('Additional named values to add to API Management for this workload.')
param namedValues array

@description('Secret named values to create, with values sourced from Azure Key Vault.')
param secretNamedValues array

@description('Additional policy fragments to add to API Management for this workload.')
param policyFragments array

@description('Operations')
param operations array

// Named Values
module createNamedValues 'named-values.bicep' = {
  name: '${uniqueString(deployment().name, apiManagementName)}-namedValues'
  params: {
    apiManagementName: apiManagementName
    namedValues: namedValues
    keyVaultName: keyVaultName
    secretNamedValues: secretNamedValues
  }
}

// Policy Fragments
module policyFragmentsModule 'policy-fragments.bicep' = {
  name: '${uniqueString(deployment().name, apiManagementName)}-policyFragmentsModule'
  params: {
    apiManagementName: apiManagementName
    policyFragments: policyFragments
  }
}

// API
module api 'api.bicep' = {
  name: '${uniqueString(deployment().name, apiManagementName)}-api'
  params: {
    apiManagementName: apiManagementName
    apiManagementLoggerName: apiManagementLoggerName
    apiDisplayName: apiDisplayName
    apiName: apiName // All lower case no special characters no spaces
    apiVersion: apiVersion
    apiUrlSuffix: apiUrlSuffix
    yaml: openApiYamlContent
    content: openApiTextContent
    productDisplayName: apiDisplayName
    productDescription: '${apiDisplayName} Product'
    subscriptionsLimit: 1
    subscriptionRequired: true
    operations: operations
  }
}
