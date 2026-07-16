const fs = require('fs');
const path = require('path');

const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const version = packageJson.version;

// Atualizar electron-builder.yml
const builderConfig = fs.readFileSync('packages/desktop/electron-builder.yml', 'utf8');
const updatedBuilder = builderConfig.replace(
  /version: \d+\.\d+\.\d+/,
  `version: ${version}`
);
fs.writeFileSync('packages/desktop/electron-builder.yml', updatedBuilder);

console.log(`✅ Version updated to ${version}`);
