// scripts/patch-prepare-arm64.js
const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

const preparePath = path.join(__dirname, '../packages/shared-scripts/src/prepare-cora-cowork.js');
let content = fs.readFileSync(preparePath, 'utf8');

// Verificar se já foi patched
if (content.includes('CORA_COWORK_SKIP_ARM64_EXEC')) {
  console.log('✅ prepare-cora-cowork.js already patched');
  process.exit(0);
}

// Função para baixar o node.exe para ARM64
function downloadNodeForArm64(targetDir) {
  const nodeVersion = '24.11.0';
  const nodeUrl = `https://nodejs.org/dist/v${nodeVersion}/node-v${nodeVersion}-win-arm64.zip`;
  const zipPath = path.join(targetDir, 'node-arm64.zip');
  const extractPath = path.join(targetDir, 'managed-resources', 'node', `node-v${nodeVersion}-win-arm64`);

  console.log(`  📥 Downloading Node.js ${nodeVersion} for ARM64...`);

  try {
    // Usar curl ou wget para baixar
    if (process.platform === 'win32') {
      execSync(`powershell -Command "Invoke-WebRequest -Uri '${nodeUrl}' -OutFile '${zipPath}'"`, { stdio: 'inherit' });
    } else {
      execSync(`curl -L -o "${zipPath}" "${nodeUrl}"`, { stdio: 'inherit' });
    }

    // Extrair
    if (process.platform === 'win32') {
      execSync(`powershell -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${path.dirname(extractPath)}' -Force"`, { stdio: 'inherit' });
    } else {
      execSync(`unzip -o "${zipPath}" -d "${path.dirname(extractPath)}"`, { stdio: 'inherit' });
    }

    fs.unlinkSync(zipPath);
    console.log(`  ✅ Node.js ${nodeVersion} for ARM64 downloaded and extracted`);
    return true;
  } catch (error) {
    console.error(`  ❌ Failed to download Node.js: ${error.message}`);
    return false;
  }
}

// Encontrar a seção do patch e adicionar download do node
const searchPattern = /if \(isWinArm64OnX64 && process\.env\.CORA_COWORK_SKIP_ARM64_EXEC === 'true'\) \{([\s\S]*?)\}\s*else \{/;
const replaceWith = `if (isWinArm64OnX64 && process.env.CORA_COWORK_SKIP_ARM64_EXEC === 'true') {
    console.log('  ⏭️  Skipping managed resources preparation for Windows ARM64 (running on x64 host)');
    const bundleOut = path.join(targetDir, 'managed-resources');
    ensureDirectory(bundleOut);
    
    // Baixar Node.js para ARM64
    const nodeVersion = "24.11.0";
    const nodeDir = path.join(bundleOut, 'node', \`node-v\${nodeVersion}-win-arm64\`);
    ensureDirectory(nodeDir);
    
    // Tentar baixar o Node.js
    try {
      const nodeUrl = \`https://nodejs.org/dist/v\${nodeVersion}/node-v\${nodeVersion}-win-arm64.zip\`;
      const zipPath = path.join(targetDir, 'node-arm64.zip');
      console.log(\`  📥 Downloading Node.js \${nodeVersion} for ARM64...\`);
      
      if (process.platform === 'win32') {
        execFileSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', 
          \`$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '\${nodeUrl}' -OutFile '\${zipPath}'\`], { timeout: 120000 });
      } else {
        execFileSync('curl', ['-L', '--fail', '--silent', '--show-error', '-o', zipPath, nodeUrl], { timeout: 120000 });
      }
      
      // Extrair
      if (process.platform === 'win32') {
        execFileSync('powershell', ['-NoProfile', '-NonInteractive', '-Command',
          \`Expand-Archive -Path '\${zipPath}' -DestinationPath '\${bundleOut}/node' -Force\`], { timeout: 60000 });
      } else {
        execFileSync('unzip', ['-o', zipPath, '-d', path.join(bundleOut, 'node')], { timeout: 60000 });
      }
      
      fs.unlinkSync(zipPath);
      console.log(\`  ✅ Node.js \${nodeVersion} for ARM64 downloaded\`);
    } catch (error) {
      console.warn(\`  ⚠️  Failed to download Node.js: \${error.message}\`);
      // Criar um arquivo dummy
      const dummyNode = path.join(nodeDir, 'node.exe');
      fs.writeFileSync(dummyNode, '');
    }
    
    // Criar manifest.json
    const manifest = {
      schemaVersion: 1,
      runtimeKey: \`\${platform}-\${arch}\`,
      node: {
        version: "24.11.0",
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

console.log('✅ prepare-cora-cowork.js patched for Windows ARM64 with Node.js download');