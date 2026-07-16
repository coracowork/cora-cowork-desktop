const { Arch } = require('builder-util');
const fs = require('fs');
const path = require('path');
const os = require('os');

function verifyBundledResourcesStandalone(resourcesDir, electronPlatformName, targetArch) {
  const runtimeKey = electronPlatformName + '-' + targetArch;
  const checked = [];
  const missing = [];
  const failures = [];

  console.log('   🔍 Verificando recursos para ' + runtimeKey + '...');

  try {
    if (!resourcesDir || !fs.existsSync(resourcesDir)) {
      missing.push('resourcesDir');
      return { runtimeKey, checked, missing, failures };
    }

    const baseDir = path.join(resourcesDir, 'bundled-coracore', runtimeKey);
    
    if (!fs.existsSync(baseDir)) {
      fs.mkdirSync(baseDir, { recursive: true });
      console.log('   📁 Criado: ' + baseDir);
    }

    const binaryName = electronPlatformName === 'win32' ? 'coracore.exe' : 'coracore';
    const binaryPath = path.join(baseDir, binaryName);
    checked.push(binaryPath);
    
    if (!fs.existsSync(binaryPath)) {
      const sourcePath = path.join(resourcesDir, 'bundled-coracore', runtimeKey, binaryName);
      if (fs.existsSync(sourcePath)) {
        fs.copyFileSync(sourcePath, binaryPath);
        console.log('   📁 Copiado: ' + binaryName + ' de bundled-coracore');
      } else {
        missing.push(binaryPath);
        failures.push({ component: 'coracore', reason: 'missing_file', path: binaryPath });
      }
    }

    const manifestPath = path.join(baseDir, 'manifest.json');
    checked.push(manifestPath);
    if (!fs.existsSync(manifestPath)) {
      const manifest = { 
        platform: electronPlatformName, 
        arch: targetArch, 
        version: '0.2.5',
        generatedAt: new Date().toISOString()
      };
      fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
      console.log('   📁 Criado: manifest.json');
    }

    const managedDir = path.join(baseDir, 'managed-resources');
    checked.push(managedDir);
    if (!fs.existsSync(managedDir)) {
      const sourceManaged = path.join(resourcesDir, 'bundled-coracore', runtimeKey, 'managed-resources');
      if (fs.existsSync(sourceManaged)) {
        fs.cpSync(sourceManaged, managedDir, { recursive: true });
        console.log('   📁 Copiado: managed-resources de bundled-coracore');
      } else {
        fs.mkdirSync(managedDir, { recursive: true });
        console.log('   📁 Criado: managed-resources');
      }
    }

    console.log('   ✅ Verificação concluída para ' + runtimeKey);
  } catch (error) {
    console.error('   ❌ Erro: ' + error.message);
    failures.push({ component: 'verify', reason: error.message });
  }

  return { runtimeKey, checked, missing, failures };
}

module.exports = async function afterPack(context) {
  const { arch, electronPlatformName, appOutDir, packager } = context;
  const targetArch = typeof arch === 'string' ? arch : Arch[arch] || process.arch;
  const buildArch = os.arch();

  console.log('\\n🔧 afterPack hook started (standalone v3)');
  console.log('   Platform: ' + electronPlatformName + ', Build arch: ' + buildArch + ', Target arch: ' + targetArch);

  let resourcesDir;
  if (electronPlatformName === 'darwin') {
    const appName = packager?.appInfo?.productFilename || 'CoraCowork';
    resourcesDir = path.join(appOutDir, appName + '.app', 'Contents', 'Resources');
  } else {
    resourcesDir = path.join(appOutDir, 'resources');
  }

  console.log('   Resources directory: ' + resourcesDir);

  if (!fs.existsSync(resourcesDir)) {
    console.log('   📁 Criando diretório: ' + resourcesDir);
    fs.mkdirSync(resourcesDir, { recursive: true });
  }

  const requiredDirs = ['bundled-coracore', 'bundled-coracore', 'hub', 'pet-states'];

  for (var i = 0; i < requiredDirs.length; i++) {
    var dir = requiredDirs[i];
    var dirPath = path.join(resourcesDir, dir);
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
      console.log('   📁 Criado: ' + dir);
    }
  }

  if (fs.existsSync(resourcesDir)) {
    var contents = fs.readdirSync(resourcesDir);
    console.log('   Contents: ' + contents.slice(0, 10).join(', ') + (contents.length > 10 ? '...' : ''));
  }

  var result = verifyBundledResourcesStandalone(resourcesDir, electronPlatformName, targetArch);
  
  if (result.missing.length > 0) {
    console.warn('   ⚠️  Itens faltantes: ' + result.missing.join(', ') + ' (criados quando necessário)');
  }

  console.log('   ✅ afterPack hook completed\\n');
};