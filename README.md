# api-to-apim

A CLI tool to deploy an API to Azure API Management given only an OpenAPI specification and XML Policy files. Uses a convention-based approach to minimise the configuration required.

As simple as:

```bash
az login
npx api-to-apim --deploy <resource-group-name>
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
         cd my-api
         npx api-to-apim --deploy sandbox
```

The tool expects these files in your directory:

- An OpenAPI 3 specification file as YAML
- Any API Management XML Policy files your API uses
- Any API Managment XML Policy Fragment files your XML Policies use, in a `fragments` directory
- A file named `yaml-params.yml` to configure deployment values

```yml
keyVaultName: "<my-keyvault-name>"
apiManagementName: "<my-apimanagement-name>"
apiManagementLoggerName: "<my-apimanagement-logger-name>"
apiDisplayName: "<API name>"
apiName: "<apiname>"
apiUrlSuffix: "<api-url-suffix>"
apiVersion: "<api-version>"
openApi: "<open-api-filename>"
namedValues: [{ key: "<my-named-value-key>", value: "<my-named-value-value>" }]
secretNamedValues: [{ key: "<my-secret-name>" }]
```

And it will do the rest.

## Prerequisites

- Node.js 18+ (or any modern Node.js runtime)
- npm
- Bash available in PATH (Git Bash works on Windows)

## Installation

```bash
npm install api-to-apim
```

## Usage

```bash
npm install api-to-apim
npm run deploy <resource-group-name>
```

OR

```bash
npx api-to-apim --deploy <resource-group-name>
```

## Required User-Provided Files

When someone uses this package in their own folder, they must provide these inputs:

- Any fragment XML files used by policies (for example `fragments/<fragment-id>.xml`).
- `yaml-params.yml` with deployment values.
- Any policy XML files referenced by the workflow (for example `api-policy.xml`, `product-policy.xml`, and operation policy files like `<operationId>.xml`).
- The OpenAPI YAML spec file referenced by `openApi` in `yaml-params.yml`.

If these files are missing, named value and fragment discovery will be incomplete and generation/deployment can fail.

### 1. YAML (`yaml-params.yml`)

Expected keys include:

- `keyVaultName`
- `apiManagementName`
- `apiManagementLoggerName`
- `apiDisplayName`
- `apiName`
- `apiUrlSuffix`
- `apiVersion`
- `openApi`
- `namedValues` (array of `{ key, value }`)
- `secretNamedValues` or `secrets` (array with `key`)

`openApi` should point to an OpenAPI file in this folder, for example:

```yaml
openApi: Healthcheck.yml
```

The generator will try these candidates in order:

1. Exact value in `openApi`
2. `<openApiBase>.yml`
3. `<openApiBase>.yaml`

### 2. OpenAPI Spec

The spec must contain `paths` entries with `operationId` values.

`list-operations.sh --ids-only <openapi-spec.yml>` is used to collect operation IDs.

### 3. Operation Policy XML Files (optional but recommended)

For each discovered operation ID, the generator looks for:

- `<operationId>.xml`

If present, dependencies are extracted with `list-policy-dependencies.sh`:

- `--fragments-only` -> APIM policy fragment IDs
- `--named-values-only` -> named value keys from `{{name}}`

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

Check the `openApi` value in `yaml-params.yml` and confirm the file exists in this folder.

### No operations found in OpenAPI

`list-operations.sh` expects a valid `paths` section and operation blocks with `operationId` values in the OpenAPI specification file.

### Bash/script execution issues on Windows

Make sure `bash` is installed and available from terminal (for example through Git Bash).

## Examples

### Generate and Deploy in One Step

1. Update `yaml-params.yml` with environment values.
2. Ensure the OpenAPI file referenced by `openApi` exists.
3. Add per-operation policy XML files named `<operationId>.xml` (optional).
4. Generate and deploy to Azure:
   ```bash
   npx api-to-apim --deploy sandbox
   ```
