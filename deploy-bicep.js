#!/usr/bin/env node

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
    stdio: 'inherit'
  });
} catch (err) {
  process.exit(err.status || 1);
}
