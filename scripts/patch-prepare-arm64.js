// scripts/patch-prepare-arm64.js
const fs = require('fs');
const path = require('path');

const preparePath = path.join(__dirname, '../packages/shared-scripts/src/prepare-cora-cowork.js');
let content = fs.readFileSync(preparePath, 'utf8');

// Verificar se já foi patched
if (content.includes('isWinArm64OnX64')) {
  console.log('✅ prepare-cora-cowork.js already patched');
  process.exit(0);
}

// Adicionar a verificação antes de prepareManagedResources
const search = `const bundledManagedResourcesDir = prepareManagedResources(targetBinaryPath, targetDir);`;
const replace = `
  // Verificar se é Windows ARM64 rodando em x64
  const isWinArm64OnX64 = platform === 'win32' && arch === 'arm64' && process.arch === 'x64';
  
  if (isWinArm64OnX64 && process.env.CORA_COWORK_SKIP_ARM64_EXEC === 'true') {
    console.log('  ⏭️  Skipping managed resources preparation for Windows ARM64 (running on x64 host)');
    const bundleOut = path.join(targetDir, 'managed-resources');
    ensureDirectory(bundleOut);
    const manifest = {
      schemaVersion: 1,
      runtimeKey: \`\${platform}-\${arch}\`,
      node: {
        version: "24.11.0",
        root: "node/node-v24.11.0-win-arm64",
        executable: "node.exe"
      },
      acpTools: []
    };
    writeJson(path.join(bundleOut, 'manifest.json'), manifest);
  } else {
    const bundledManagedResourcesDir = prepareManagedResources(targetBinaryPath, targetDir);
  }
`;

content = content.replace(search, replace);
fs.writeFileSync(preparePath, content);

console.log('✅ prepare-cora-cowork.js patched for Windows ARM64');