using 'main.bicep'

param keyVaultName = 'kv-drc-config-prd-ae'
param apiManagementName = 'apim-ae-demo-int-01-apim'
param apiManagementLoggerName = 'appi-quotables-prd-ae-01'
param apiDisplayName = 'Example API'
param apiName = 'example'
param apiUrlSuffix = 'example'
param apiVersion = 'v1'
param openApiTextContent = loadTextContent('Example.yml')
param openApiYamlContent = loadYamlContent('Example.yml')
param namedValues = [
  {
    key: 'backend-service'
    value: 'http://todo'
  }
  {
    key: 'forward-request-timeout'
    value: '30'
  }
  {
    key: 'limit-concurrency-key'
    value: '@(context.Request.IpAddress)'
  }
  {
    key: 'limit-concurrency-max-count'
    value: '1'
  }
  {
    key: 'quota-by-key-calls'
    value: '1'
  }
  {
    key: 'quota-by-key-renewal-period-seconds'
    value: '300'
  }
  {
    key: 'rate-limit-by-key-calls'
    value: '1'
  }
  {
    key: 'rate-limit-by-key-renewal-period-seconds'
    value: '300'
  }
  {
    key: 'retry-count'
    value: '1'
  }
  {
    key: 'retry-delta'
    value: '3'
  }
  
]
param secretNamedValues = [
  
]
param policyFragments = [
{
    id: 'clean-outbound'
    format: 'xml'
    value: loadTextContent('fragments/clean-outbound.xml')
  }
{
    id: 'limit-concurrency-retry'
    format: 'xml'
    value: loadTextContent('fragments/limit-concurrency-retry.xml')
  }
{
    id: 'quota-by-key'
    format: 'xml'
    value: loadTextContent('fragments/quota-by-key.xml')
  }
{
    id: 'rate-limit-by-key'
    format: 'xml'
    value: loadTextContent('fragments/rate-limit-by-key.xml')
  }
{
    id: 'x-correlation-id-inbound'
    format: 'xml'
    value: loadTextContent('fragments/x-correlation-id-inbound.xml')
  }
{
    id: 'x-correlation-id-outbound'
    format: 'xml'
    value: loadTextContent('fragments/x-correlation-id-outbound.xml')
  }
]
param operations = [
  {
    operationName: 'get-example'
    operationPoliciesTextContent: [
      {
        key: 'get-example'
        value: loadTextContent('./get-example.xml')
      }
    ]
  }
]
