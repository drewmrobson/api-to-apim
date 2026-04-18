# api-to-apim

A convention-based CLI tool to deploy an API to Azure API Management from an OpenAPI specification and XML Policy files.

Given an existing [Azure API Management](https://azure.microsoft.com/en-au/products/api-management) service, APIs need to be deployed to this service as atomic units-of-work. Run this tool in the working directory containg the API definition, the associated [XML Policy](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-policies) files, and any dependent [XML Policy Fragements](https://learn.microsoft.com/en-us/azure/api-management/policy-fragments). The tool will perform discovery on these files, build out deployment parameters and deploy it all to your target API Management service.

## Usage

Required working directory structure:

```bash
<working-dir>/
├─ api.yml                    # OpenAPI 3 API Definition
├─ api-params.yml             # Configuration for this deployment as below
├─ api-policy.xml             # XML Policy file for the API
├─ product-policy.xml         # XML Policy file for the API Product
├─ get-example.xml            # XML Policy file for the API Operation GET /example
└─ fragments/
   └─ rate-limit-by-key.xml   # XML Policy Fragments used in the above policies
```

Run local:

```bash
cd <working-dir>                                # Navigate to the API definition directory
az login                                        # Log in to the target subscription
npx api-to-apim --deploy <resource-group-name>  # Deploy the API to Azure API Management
```

Or in an Azure DevOps YAML Pipeline

```yml
-  task: AzureCLI@2
   displayName: "Deploy API"
   inputs:
      azureSubscription: "${{ parameters.azureSubscription }}"
      scriptLocation: "inlineScript"
      scriptType: "bash"
      inlineScript: |
         cd <working-dir>                                # Navigate to the API definition directory
         npx api-to-apim --deploy <resource-group-name>  # Deploy the API to Azure API Management
```

### api-params.yml

The `api-params.yml` file provides configuration the tool needs to deploy to Azure.

```yml
# Resource name of Azure Key Vault for Named Values that are Key Vault-backed.
keyVaultName: "<my-keyvault-name>"

# Resource name of Azure API Management to deploy the API to.
apiManagementName: "<my-apimanagement-name>"

# Resource name of type `Microsoft.ApiManagement/service/loggers`.
apiManagementLoggerName: "<my-apimanagement-logger-name>"

# Friendly name of the API, e.g. Petstore.
apiDisplayName: "<API name>"

# API ID - Friendly name in all lowercase, no spaces.
apiName: "<apiname>"

# API path suffix, e.g. https://petstore.swagger.io/v2/<api-url-suffix>
apiUrlSuffix: "<api-url-suffix>"

# API versioning via path, e.g. https://petstore.swagger.io/<api-version>/pets
apiVersion: "<api-version>"

# Filename of the OpenAPI 3 specification API file definition in YAML format, e.g. api.yml.
openApi: "<open-api-filename>"

# Key-Value pairs of non-secret Named Values your XML Policies requires to be created in API Management.
namedValues: [{ key: "<my-named-value-key>", value: "<my-named-value-value>" }]

# Key names of existing Key Vault Secrets to create Named Values from.
secretNamedValues: [{ key: "<my-secret-name>" }]
```

### Conventions

This tool uses some conventions and assumptions to reduce the amount of configuration required.

1. The tool doesn't require any files to be specified; it operates on the files in the working directory.
   - With the exception of `api.yml`, the OpenAPI 3 Definition can be the API name and the `openAPI` parameter links this.
2. An Azure Key Vault with required secrets already exists.
3. An Azure API Management Service with an Application Insights logger attached already exists.
4. The name of a fragment file is the same as the fragment ID.
5. For each discovered operation ID, the tool looks for `<operationId>.xml`
5. The API Definition file must contain `paths` entries with `operationId` values.

## Installation

Requires:

- Node.js 18+ (or any modern Node.js runtime)
- npm
- Bash available in PATH (Git Bash works on Windows)

Install via npm:

```bash
npm install api-to-apim
```
## Troubleshooting

### Missing dependencies

Error:

```text
Missing dependencies. Install with: npm install
```

Fix:

```bash
npm install
```

### OpenAPI file not found

Check the `openApi` value in `api-params.yml` and confirm the file exists in this folder.

### No operations found in OpenAPI

`list-operations.sh` expects a valid `paths` section and operation blocks with `operationId` values in the OpenAPI specification file.

### Bash/script execution issues on Windows

Make sure `bash` is installed and available from terminal (for example through Git Bash).

## Examples

Examples can be found in the [example](./example/) folder.
