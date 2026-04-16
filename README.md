# Bicep Params Generator

This folder contains a small toolchain that generates a `.bicepparam` file from:

- YAML configuration (`yaml-params.yml`)
- OpenAPI operations discovered by `list-operations.sh`
- Policy dependencies discovered by `list-policy-dependencies.sh`
- A Nunjucks template (`template.njk`)

## Files

- `api-to-apim.js`: Orchestrator for generate + deploy workflow.
- `generate-bicep.js`: Generates the `.bicepparam` file from YAML, OpenAPI, and policies.
- `deploy-bicep.js`: Wrapper for deploying Bicep templates to Azure.
- `template.njk`: Nunjucks template for the output `.bicepparam` file.
- `yaml-params.yml`: Base input values.
- `list-operations.sh`: Extracts operation IDs from the OpenAPI spec. Usage: `./list-operations.sh [--ids-only] <openapi-spec.yml>`
- `list-policy-dependencies.sh`: Extracts policy fragment IDs and named values from policy XML files.
- `check-fragments.sh`: Utility script for checking APIM fragment existence in Azure.
- `run-bicep.sh`: Deploys the Bicep template to Azure (takes resource-group as argument).

## Prerequisites

- Node.js 18+ (or any modern Node.js runtime)
- npm
- Bash available in PATH (Git Bash works on Windows)

Install dependencies:

```bash
npm install
```

## CLI Package Usage

This project is configured as an npm CLI package with three separate commands for different workflows.

### Development (local npm scripts)

Generate the Bicep parameters file:

```bash
npm run generate
```

Deploy to Azure (requires resource group):

```bash
npm run deploy sandbox
```

### Direct Node execution

Use individual scripts directly:

```bash
node generate-bicep.js                           # Generate only
node deploy-bicep.js sandbox                     # Deploy only
node api-to-apim.js                              # Generate only (same as generate-bicep)
node api-to-apim.js --deploy sandbox             # Generate AND deploy in one step
```

### npx usage (CLI package)

When installed:

```bash
npx generate-bicep                                # Generate only
npx deploy-bicep sandbox                         # Deploy only
npx api-to-apim                                  # Generate only
npx api-to-apim --deploy sandbox                 # Generate AND deploy in one step
```

Install globally and run anywhere:

```bash
npm install -g .
api-to-apim                                      # Generate only
api-to-apim --deploy sandbox                     # Generate AND deploy
generate-bicep                                   # Generate only
deploy-bicep sandbox                             # Deploy only
```

Preview package contents before publish:

```bash
npm run pack:dry-run
```

## Quick Start

### Generate only (default)

```bash
npx api-to-apim
```

Reads `yaml-params.yml`, `template.njk` and writes `generated.bicepparam`.

### Generate and deploy (one step)

```bash
npx api-to-apim --deploy sandbox
```

Generates the `.bicepparam` file and immediately deploys to the `sandbox` resource group.

### Just deploy (after generating separately)

```bash
npx deploy-bicep sandbox
```

### Custom input/output paths

```bash
npx api-to-apim custom.yml template.njk output.bicepparam
```

Or with deployment:

```bash
npx api-to-apim --deploy sandbox custom.yml template.njk output.bicepparam
```

Show usage:

```bash
npx api-to-apim --help
npx generate-bicep --help
npx deploy-bicep --help
```

## Input Expectations

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

## What the Generator Produces

The rendered `.bicepparam` file includes:

- Core API values from YAML
- `operations` from OpenAPI operation IDs
- `policyFragments` discovered from operation XML policies
- `namedValues` merged from YAML + discovered policy named values
- `secretNamedValues` (from `secretNamedValues` or `secrets` in YAML)

When a named value key is discovered in policy XML but not defined in YAML, it is added with an empty value:

```json
{ "key": "some-named-value", "value": "" }
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

Check the `openApi` value in `yaml-params.yml` and confirm the file exists in this folder.

### No operations found in OpenAPI

`list-operations.sh` expects a valid `paths` section and operation blocks with `operationId` values.

### Bash/script execution issues on Windows

Make sure `bash` is installed and available from terminal (for example through Git Bash).

## Example Workflow

### Option 1: Generate and Deploy in One Step

1. Update `yaml-params.yml` with environment values.
2. Ensure the OpenAPI file referenced by `openApi` exists.
3. Add per-operation policy XML files named `<operationId>.xml` (optional).
4. Generate and deploy to Azure:
   ```bash
   npx api-to-apim --deploy sandbox
   ```

### Option 2: Generate First, Review, Then Deploy

1. Update `yaml-params.yml` with environment values.
2. Ensure the OpenAPI file referenced by `openApi` exists.
3. Add per-operation policy XML files named `<operationId>.xml` (optional).
4. Generate the Bicep parameters file:
   ```bash
   npx api-to-apim
   ```
5. Review `generated.bicepparam` before deployment.
6. Deploy to Azure when ready:
   ```bash
   npx deploy-bicep sandbox
   ```
