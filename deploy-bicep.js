#!/usr/bin/env node
/**
 * Deploys generated Bicep templates to Azure by invoking run-bicep.sh with the specified
 * resource group. Used as the deployment step after generating Bicep parameter files.
 */

const { execFileSync } = require('child_process');
const path = require('path');

const resourceGroup = process.argv[2];

if (resourceGroup === '--help' || resourceGroup === '-h') {
  console.error('Usage: deploy-bicep <resource-group>');
  console.error('Example: deploy-bicep sandbox');
  process.exit(0);
}

if (!resourceGroup) {
  console.error('Usage: deploy-bicep <resource-group>');
  console.error('Example: deploy-bicep sandbox');
  process.exit(1);
}

const scriptPath = path.resolve(__dirname, 'run-bicep.sh');

try {
  execFileSync('bash', [scriptPath, resourceGroup], {
    cwd: process.cwd(),
    stdio: 'inherit'
  });
} catch (err) {
  process.exit(err.status || 1);
}
