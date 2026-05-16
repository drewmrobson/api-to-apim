#!/usr/bin/env node
/**
 * CLI tool for converting OpenAPI specifications to Azure API Management (APIM) Bicep deployments.
 * Generates Bicep parameter files from YAML configuration and Nunjucks templates, with optional
 * deployment to a specified Azure resource group.
 */

const path = require('path');
const { execFileSync } = require('child_process');

const cwd = process.cwd();
const packageRoot = __dirname;

function usage() {
  console.error('Usage: npx api-to-apim [--deploy <resourceGroup>] [yamlFile] [templateFile] [outputFile]');
  console.error('');
  console.error('Modes:');
  console.error('  npx api-to-apim                                                        # Generate only');
  console.error('  npx api-to-apim --deploy <resourceGroup>                               # Generate and deploy');
  console.error('  npx api-to-apim <yamlFile> <templateFile> <outputFile>');
  console.error('  npx api-to-apim --deploy <resourceGroup> <yamlFile> <templateFile> <outputFile>');
  console.error('');
  console.error('Defaults: api-params.yml template.njk generated.bicepparam');
}

function parseArgs(args) {
  let resourceGroup = null;
  const fileArgs = [];
  let i = 0;
  while (i < args.length) {
    if (args[i] === '--deploy' || args[i] === '-d') {
      if (i + 1 >= args.length) {
        throw new Error(`${args[i]} requires a resource group name`);
      }
      resourceGroup = args[++i];
    } else {
      fileArgs.push(args[i]);
    }
    i++;
  }
  return { resourceGroup, fileArgs };
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    usage();
    process.exit(0);
  }

  const { resourceGroup, fileArgs } = parseArgs(args);

  // Generate the bicepparam file
  const generateScript = path.resolve(packageRoot, 'generate-bicep.js');
  execFileSync('node', [generateScript, ...fileArgs], {
    cwd,
    stdio: 'inherit'
  });

  // If --deploy was specified, deploy
  if (resourceGroup) {
    console.log(`\nDeploying to resource group: ${resourceGroup}`);
    const deployScript = path.resolve(packageRoot, 'deploy-bicep.js');
    execFileSync('node', [deployScript, resourceGroup], {
      cwd,
      stdio: 'inherit'
    });
  }
}

try {
  main();
} catch (err) {
  if (!err.status) console.error(`Error: ${err.message}`);
  process.exit(err.status || 1);
}
