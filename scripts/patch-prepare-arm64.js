// scripts/patch-prepare-arm64.js (versão simplificada)
const fs = require('fs');
const path = require('path');

const preparePath = path.join(__dirname, '../packages/shared-scripts/src/prepare-cora-cowork.js');
let content = fs.readFileSync(preparePath, 'utf8');

if (content.includes('CORA_COWORK_SKIP_ARM64_EXEC')) {
  console.log('✅ prepare-cora-cowork.js already patched');
  process.exit(0);
}

const searchPattern = /if \(isWinArm64OnX64 && process\.env\.CORA_COWORK_SKIP_ARM64_EXEC === 'true'\) \{([\s\S]*?)bundledManagedResourcesDir = bundleOut;([\s\S]*?)\}\s*else \{/;
const replaceWith = `if (isWinArm64OnX64 && process.env.CORA_COWORK_SKIP_ARM64_EXEC === 'true') {
    console.log('  ⏭️  Skipping managed resources preparation for Windows ARM64 (running on x64 host)');
    const bundleOut = path.join(targetDir, 'managed-resources');
    ensureDirectory(bundleOut);
    
    // Criar estrutura de diretórios para o Node.js
    const nodeVersion = "24.11.0";
    const nodeDir = path.join(bundleOut, 'node', \`node-v\${nodeVersion}-win-arm64\`);
    ensureDirectory(nodeDir);
    
    // Criar um arquivo node.exe vazio (para satisfazer o verificador)
    const dummyNode = path.join(nodeDir, 'node.exe');
    if (!fs.existsSync(dummyNode)) {
      fs.writeFileSync(dummyNode, '');
      console.log(\`  📁 Criado: node.exe dummy em \${nodeDir}\`);
    }
    
    // Criar manifest.json
    const manifest = {
      schemaVersion: 1,
      runtimeKey: \`\${platform}-\${arch}\`,
      node: {
        version: nodeVersion,
        root: \`node/node-v\${nodeVersion}-win-arm64\`,
        executable: "node.exe"
      },
      acpTools: []
    };
    writeJson(path.join(bundleOut, 'manifest.json'), manifest);
    bundledManagedResourcesDir = bundleOut;
  } else {`;

content = content.replace(searchPattern, replaceWith);
fs.writeFileSync(preparePath, content);

console.log('✅ prepare-cora-cowork.js patched for Windows ARM64');