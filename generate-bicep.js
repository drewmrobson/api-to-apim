#!/usr/bin/env node

/**
 * generate-bicep.js
 *
 * Generates a Bicep parameters file (.bicepparam) for deploying an API to Azure API Management.
 *
 * Reads a YAML configuration file (default: api-params.yml) containing required fields such as
 * the API name, APIM instance, Key Vault reference, and OpenAPI spec path. It then:
 *   1. Extracts operation IDs from the OpenAPI spec via list-operations.sh
 *   2. Discovers policy XML files for each operation plus api/product-level policies
 *   3. Recursively resolves policy fragment and named value dependencies via list-policy-dependencies.sh
 *   4. Merges discovered named values with those declared in the YAML
 *   5. Renders all collected data through a Nunjucks template (default: template.njk)
 *   6. Writes the rendered output to a .bicepparam file (default: generated.bicepparam)
 *   7. Copies bundled Bicep module files (main.bicep, api.bicep, etc.) into the working directory
 *
 * Usage: node generate-bicep.js [yamlFile] [templateFile] [outputFile]
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

let yaml;
let nunjucks;

try {
  yaml = require('js-yaml');
  nunjucks = require('nunjucks');
} catch (err) {
  console.error('Missing dependencies. Install with: npm install js-yaml nunjucks');
  process.exit(1);
}

const cwd = process.cwd();
const packageRoot = __dirname;

function usage() {
  console.error('Usage: node generate-bicep.js [yamlFile] [templateFile] [outputFile]');
  console.error('Defaults: api-params.yml template.njk generated.bicepparam');
}

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function runScript(scriptPath, args) {
  try {
    return execFileSync('bash', [scriptPath, ...args], {
      cwd,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe']
    }).trim();
  } catch (err) {
    const stderr = err.stderr ? String(err.stderr).trim() : '';
    const stdout = err.stdout ? String(err.stdout).trim() : '';
    const details = stderr || stdout || err.message;
    throw new Error(`Failed running ${path.basename(scriptPath)}: ${details}`);
  }
}

function linesToList(text) {
  if (!text) {
    return [];
  }
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function uniqSorted(list) {
  return [...new Set(list)].sort((a, b) => a.localeCompare(b));
}

function hasFile(filePath) {
  return fs.existsSync(filePath) && fs.statSync(filePath).isFile();
}

function resolveHelperScript(fileName) {
  const cwdScriptPath = path.resolve(cwd, fileName);
  if (hasFile(cwdScriptPath)) {
    return cwdScriptPath;
  }

  const packagedScriptPath = path.resolve(packageRoot, fileName);
  if (hasFile(packagedScriptPath)) {
    return packagedScriptPath;
  }

  throw new Error(
    `Required script not found: ${fileName}. Checked ${cwdScriptPath} and ${packagedScriptPath}`
  );
}

function discoverPolicyFiles(cwdPath, operationIds) {
  const operationPolicyFiles = operationIds
    .map((operationId) => path.resolve(cwdPath, `${operationId}.xml`))
    .filter((filePath) => hasFile(filePath));

  const wellKnownPolicyFiles = [
    path.resolve(cwdPath, 'api-policy.xml'),
    path.resolve(cwdPath, 'product-policy.xml')
  ].filter((filePath) => hasFile(filePath));

  return uniqSorted([...wellKnownPolicyFiles, ...operationPolicyFiles]);
}

function collectPolicyDependencies(entryPolicyFiles, listPolicyDepsScript, cwdPath) {
  const visitedFiles = new Set();
  const discoveredFragmentIds = new Set();
  const discoveredNamedValueKeys = new Set();
  const queue = [...entryPolicyFiles];

  while (queue.length > 0) {
    const policyXmlPath = queue.shift();
    if (!policyXmlPath || visitedFiles.has(policyXmlPath) || !hasFile(policyXmlPath)) {
      continue;
    }

    visitedFiles.add(policyXmlPath);

    const fragmentsOutput = runScript(listPolicyDepsScript, ['--fragments-only', policyXmlPath]);
    const fragmentIds = linesToList(fragmentsOutput);

    for (const fragmentId of fragmentIds) {
      discoveredFragmentIds.add(fragmentId);

      const fragmentFilePath = path.resolve(cwdPath, 'fragments', `${fragmentId}.xml`);
      if (hasFile(fragmentFilePath) && !visitedFiles.has(fragmentFilePath)) {
        queue.push(fragmentFilePath);
      }
    }

    const namedValuesOutput = runScript(listPolicyDepsScript, ['--named-values-only', policyXmlPath]);
    const namedValueKeys = linesToList(namedValuesOutput);

    for (const key of namedValueKeys) {
      discoveredNamedValueKeys.add(key);
    }
  }

  return {
    fragments: uniqSorted([...discoveredFragmentIds]),
    namedValueKeys: uniqSorted([...discoveredNamedValueKeys])
  };
}

function ensureArray(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeSecretEntries(rawSecrets) {
  return ensureArray(rawSecrets)
    .map((item) => {
      if (typeof item === 'string') {
        return { key: item };
      }
      if (item && typeof item === 'object' && typeof item.key === 'string') {
        return { key: item.key };
      }
      return null;
    })
    .filter(Boolean);
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    usage();
    process.exit(0);
  }

  const yamlFile = path.resolve(cwd, args[0] || 'api-params.yml');
  const templateFile = args[1] ? path.resolve(cwd, args[1]) : resolveHelperScript('template.njk');
  const outputFile = path.resolve(cwd, args[2] || 'generated.bicepparam');

  if (!hasFile(yamlFile)) {
    throw new Error(`YAML input not found: ${yamlFile}`);
  }
  if (args[1] && !hasFile(templateFile)) {
    throw new Error(`Template input not found: ${templateFile}`);
  }

  const listOpsScript = resolveHelperScript('list-operations.sh');
  const listPolicyDepsScript = resolveHelperScript('list-policy-dependencies.sh');

  // Copy bundled Bicep files into cwd so `using 'main.bicep'` and `az deployment` resolve correctly
  const bicepFiles = ['main.bicep', 'api.bicep', 'named-values.bicep', 'policy-fragments.bicep'];
  for (const file of bicepFiles) {
    const src = path.resolve(packageRoot, file);
    if (hasFile(src)) fs.copyFileSync(src, path.resolve(cwd, file));
  }

  const yamlInput = yaml.load(readText(yamlFile)) || {};
  if (!yamlInput || typeof yamlInput !== 'object') {
    throw new Error('YAML file does not contain a mapping/object at the root.');
  }

  const requiredFields = ['keyVaultName', 'apiManagementName', 'apiManagementLoggerName', 'apiDisplayName', 'apiName', 'apiUrlSuffix', 'apiVersion', 'openApi'];
  const missingFields = requiredFields.filter((field) => !yamlInput[field]);
  if (missingFields.length > 0) {
    throw new Error(`Missing required YAML fields: ${missingFields.join(', ')}`);
  }

  const openApiValue = typeof yamlInput.openApi === 'string' ? yamlInput.openApi : '';
  const openApiBase = openApiValue.replace(/\.[^.]+$/, '');

  const openApiCandidates = [...new Set([
    openApiValue,
    `${openApiBase}.yml`,
    `${openApiBase}.yaml`
  ].filter(Boolean))].map((candidate) => path.resolve(cwd, candidate));

  const openApiSpec = openApiCandidates.find((candidate) => hasFile(candidate));

  if (!openApiSpec) {
    throw new Error(
      `OpenAPI spec referenced by 'openApi' was not found. Checked: ${openApiCandidates.join(', ')}`
    );
  }

  const operationIdsOutput = runScript(listOpsScript, ['--ids-only', openApiSpec]);
  const operations = uniqSorted(linesToList(operationIdsOutput));

  const operationsWithoutXml = operations.filter((op) => !hasFile(path.resolve(cwd, `${op}.xml`)));
  if (operationsWithoutXml.length > 0) {
    console.warn(`Warning: ${operationsWithoutXml.length} operation(s) have no policy XML file and will cause a Bicep compile error: ${operationsWithoutXml.join(', ')}`);
  }

  const policyFilesToScan = discoverPolicyFiles(cwd, operations);
  const dependencyData = collectPolicyDependencies(policyFilesToScan, listPolicyDepsScript, cwd);
  const mergedFragments = dependencyData.fragments;

  const yamlNamedValues = ensureArray(yamlInput.namedValues).filter(
    (entry) => entry && typeof entry === 'object' && typeof entry.key === 'string'
  );

  const existingNamedValueKeys = new Set(yamlNamedValues.map((entry) => entry.key));
  const mergedNamedValues = [
    ...yamlNamedValues,
    ...dependencyData.namedValueKeys
      .filter((key) => !existingNamedValueKeys.has(key))
      .map((key) => ({ key, value: '' }))
  ];

  const secretEntries = normalizeSecretEntries(yamlInput.secretNamedValues || yamlInput.secrets);

  const templateContext = {
    ...yamlInput,
    openApi: openApiBase,
    operations,
    policyFragments: mergedFragments,
    namedValues: mergedNamedValues,
    secrets: secretEntries
  };

  const rendered = nunjucks.renderString(readText(templateFile), templateContext);
  fs.writeFileSync(outputFile, `${rendered.trimEnd()}\n`, 'utf8');

  console.log(`Generated ${path.relative(cwd, outputFile)} with ${operations.length} operation(s), ${mergedFragments.length} fragment(s), and ${mergedNamedValues.length} named value(s).`);
}

try {
  main();
} catch (err) {
  console.error(`Error: ${err.message}`);
  process.exit(1);
}
