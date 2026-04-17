@description('Existing target API Management instance')
param apiManagementName string

@description('Name of the API Management Logger to use for this workload. This logger must already exist in the API Management instance specified by apiManagementName.')
param apiManagementLoggerName string

@description('Display name of the API')
@maxLength(30)
param apiDisplayName string

@description('Name of the API')
@maxLength(30)
param apiName string

@description('API major Version')
param apiVersion string

@description('API path suffix')
param apiUrlSuffix string

@description('The OpenAPI specification as a YAML object')
param yaml object

@description('The OpenAPI specification as a string')
param content string

@description('Product display name')
param productDisplayName string

@description('Product description')
param productDescription string

@description('Number of subscribers this API Product can have.')
param subscriptionsLimit int

@description('Operations')
param operations array

@description('Enable or disable subscription key requirement for an api. By default, this is enabled.')
param subscriptionRequired bool

// Existing API Management Service
resource apiManagement 'Microsoft.ApiManagement/service@2024-10-01-preview' existing = {
  name: apiManagementName
}

// Get existing API Management logger for Application Insights
resource apiManagementLogger 'Microsoft.ApiManagement/service/loggers@2024-10-01-preview' existing = {
  name: apiManagementLoggerName
  parent: apiManagement
}

// Version Set
resource apiVersionSet 'Microsoft.ApiManagement/service/apiVersionSets@2024-10-01-preview' = {
  name: '${apiName}-versionset'
  parent: apiManagement
  properties: {
    description: yaml.info.description
    displayName: '${apiDisplayName} API'
    versioningScheme: 'Segment'
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2024-10-01-preview' = {
  parent: apiManagement
  name: apiName
  properties: {
    // Note:
    //  Display Name comes from info.title in openapi spec unless overriden
    //  Description comes from info.description in openapi spec unless overriden
    //  serviceUrl comes from servers first url in openapi spec unless overriden
    apiType: 'http'
    apiVersion: apiVersion
    apiVersionSetId: apiVersionSet.id
    format: 'openapi' // OpenAPI 3 YAML
    path: apiUrlSuffix
    protocols: [
      'https'
    ]
    isCurrent: true
    subscriptionRequired: subscriptionRequired
    type: 'http'
    value: content
    subscriptionKeyParameterNames: {
      header: 'x-api-key'
      query: 'DONOTUSE'
    }
  }
}

// Add logging to this API
resource apiMonitoring 'Microsoft.ApiManagement/service/apis/diagnostics@2024-10-01-preview' = {
  name: 'applicationinsights'
  parent: api
  properties: {
    httpCorrelationProtocol: 'W3C'
    alwaysLog: 'allErrors'
    loggerId: apiManagementLogger.id
    verbosity: 'information'
    logClientIp: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: ['x-api-key', 'x-correlation-id'] // Only log these headers
        body: { bytes: 0 } // Disable request body capture
      }
      response: {
        headers: ['x-correlation-id']
        body: { bytes: 0 }
      }
    }
    backend: {
      request: {
        headers: ['x-correlation-id']
        body: { bytes: 0 }
      }
      response: {
        headers: ['x-correlation-id']
        body: { bytes: 0 }
      }
    }
  }
}

// Add Product
resource product 'Microsoft.ApiManagement/service/products@2024-10-01-preview' = {
  name: '${apiName}-product'
  parent: apiManagement
  properties: {
    approvalRequired: true
    description: productDescription
    displayName: productDisplayName
    state: 'published'
    subscriptionRequired: true
    subscriptionsLimit: subscriptionsLimit
    terms: 'No Terms'
  }
  dependsOn: [api]
}

// Product Subscription
resource productSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-10-01-preview' = {
  parent: apiManagement
  name: '${apiName}-product-sub'
  properties: {
    allowTracing: false
    displayName: productDisplayName
    scope: product.id
    state: 'active'
  }
}

resource productLink 'Microsoft.ApiManagement/service/products/apiLinks@2024-10-01-preview' = {
  name: '${product.name}-productLink'
  parent: product
  properties: {
    apiId: api.id
  }
  dependsOn: [api, product]
}

// Product Policy
resource productPolicy 'Microsoft.ApiManagement/service/products/policies@2024-10-01-preview' = {
  name: 'policy'
  parent: product
  properties: {
    format: 'xml'
    value: loadTextContent('./product-policy.xml')
  }
  dependsOn: [api, product]
}

// API Policy
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-10-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'xml'
    value: loadTextContent('./api-policy.xml')
  }
  dependsOn: [api]
}

// Get existing operations created from OpenAPI3
resource op 'Microsoft.ApiManagement/service/apis/operations@2024-10-01-preview' existing = [
  for o in operations: {
    name: o.operationName
    parent: api
  }
]

// Attach/overwrite the policy under each existing operation
resource opPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-10-01-preview' = [
  for (o, i) in operations: {
    name: 'policy'
    parent: op[i]
    properties: {
      format: 'xml'
      value: length(filter(o.operationPoliciesTextContent, p => p.key == o.operationName)) > 0
        ? first(filter(o.operationPoliciesTextContent, p => p.key == o.operationName)).value
        : first(o.operationPoliciesTextContent).value
    }
  }
]

@description('Resource ID of the APIM API.')
output apiId string = api.id
