const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const os = require('os');

function backendBinaryName(platform) {
  // Match the binary name used by prepare-cora-cowork.js and other scripts
  // Windows build produces 'cora-cowork-app.exe'; other platforms use 'CoraCore'
  return platform === 'win32' ? 'cora-cowork-app.exe' : 'CoraCore';
}

function nodeBinaryName(platform) {
  return platform === 'win32' ? 'node.exe' : 'node';
}

function nodeExecutableParts(platform) {
  return platform === 'win32' ? [nodeBinaryName(platform)] : ['bin', nodeBinaryName(platform)];
}

function normalize(relativePath) {
  return relativePath.split(path.sep).join('/');
}

function bundledPath(runtimeKey, ...parts) {
  return normalize(path.join('bundled-cora-cowork', runtimeKey, ...parts));
}

function requireRelativePath(baseDir, runtimeKey, parts, checked, missing) {
  const relativePath = bundledPath(runtimeKey, ...parts);
  checked.push(relativePath);

  if (!isFile(path.join(baseDir, ...parts))) {
    missing.push(relativePath);
  }
}

function requireRelativeDirectory(baseDir, runtimeKey, parts, checked, missing) {
  const relativePath = bundledPath(runtimeKey, ...parts);
  checked.push(relativePath);

  const fullPath = path.join(baseDir, ...parts);
  if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isDirectory()) {
    missing.push(relativePath);
  }
}

function readDirectories(root) {
  if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) return [];

  return fs
    .readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .toSorted();
}

function isFile(filePath) {
  return fs.existsSync(filePath) && fs.statSync(filePath).isFile();
}

function requireFile(baseDir, runtimeKey, parts, checked, missing) {
  const relativePath = bundledPath(runtimeKey, ...parts);
  checked.push(relativePath);

  if (!isFile(path.join(baseDir, ...parts))) {
    missing.push(relativePath);
  }
}

function requireDirectory(baseDir, runtimeKey, parts, checked, missing) {
  const relativePath = bundledPath(runtimeKey, ...parts);
  checked.push(relativePath);

  const fullPath = path.join(baseDir, ...parts);
  if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isDirectory()) {
    missing.push(relativePath);
  }
}

function verifyBundleManifest(baseDir, runtimeKey, electronPlatformName, targetArch, checked, missing) {
  const parts = ['manifest.json'];
  const relativePath = bundledPath(runtimeKey, ...parts);
  const manifestPath = path.join(baseDir, ...parts);
  checked.push(relativePath);

  if (!isFile(manifestPath)) {
    missing.push(relativePath);
    return;
  }

  const manifest = readManifest(manifestPath);
  if (!manifest) {
    missing.push(`${relativePath}<invalid-json>`);
    return;
  }

  if (manifest.platform !== electronPlatformName) {
    missing.push(`${relativePath}<platform:${electronPlatformName}>`);
  }

  if (manifest.arch !== targetArch) {
    missing.push(`${relativePath}<arch:${targetArch}>`);
  }
}

function requireManagedNode(baseDir, runtimeKey, platform, checked, missing) {
  const nodeRoot = path.join(baseDir, 'managed-resources', 'node');
  const versions = readDirectories(nodeRoot);
  const executableParts = nodeExecutableParts(platform);

  if (versions.length === 0) {
    const relativePath = bundledPath(runtimeKey, 'managed-resources', 'node', '*', ...executableParts);
    checked.push(relativePath);
    missing.push(relativePath);
    return;
  }

  for (const version of versions) {
    requireFile(baseDir, runtimeKey, ['managed-resources', 'node', version, ...executableParts], checked, missing);
  }
}

const CODEX_VENDOR_TRIPLE_BY_RUNTIME_KEY = {
  'win32-arm64': 'aarch64-pc-windows-msvc',
  'win32-x64': 'x86_64-pc-windows-msvc',
};

function acpToolPlatformExecutableParts(platform, runtimeKey, toolId) {
  if (platform !== 'win32') return null;

  if (toolId === 'codex-acp') {
    const vendorTriple = CODEX_VENDOR_TRIPLE_BY_RUNTIME_KEY[runtimeKey];
    if (!vendorTriple) return null;

    return ['node_modules', '@openai', `codex-${runtimeKey}`, 'vendor', vendorTriple, 'bin', 'codex.exe'];
  }

  if (toolId === 'claude-agent-acp') {
    return ['node_modules', '@anthropic-ai', `claude-agent-sdk-${runtimeKey}`, 'claude.exe'];
  }

  return null;
}

function readManifest(manifestPath) {
  try {
    return JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch {
    return null;
  }
}

function requireManagedAcpTool(baseDir, runtimeKey, platform, toolId, checked, missing) {
  const toolRoot = path.join(baseDir, 'managed-resources', 'acp', toolId);
  const versions = readDirectories(toolRoot);

  if (versions.length === 0) {
    const relativePath = bundledPath(runtimeKey, 'managed-resources', 'acp', toolId, '*', runtimeKey, 'manifest.json');
    checked.push(relativePath);
    missing.push(relativePath);
    return;
  }

  for (const version of versions) {
    const platformRoot = path.join(toolRoot, version, runtimeKey);
    const manifestRelativePath = bundledPath(
      runtimeKey,
      'managed-resources',
      'acp',
      toolId,
      version,
      runtimeKey,
      'manifest.json'
    );
    checked.push(manifestRelativePath);

    const manifestPath = path.join(platformRoot, 'manifest.json');
    if (!isFile(manifestPath)) {
      missing.push(manifestRelativePath);
      continue;
    }

    const manifest = readManifest(manifestPath);
    const entrypoint = typeof manifest?.entrypoint === 'string' ? manifest.entrypoint : null;
    if (!entrypoint) {
      missing.push(bundledPath(runtimeKey, 'managed-resources', 'acp', toolId, version, runtimeKey, '<entrypoint>'));
      continue;
    }

    const entrypointRelativePath = bundledPath(
      runtimeKey,
      'managed-resources',
      'acp',
      toolId,
      version,
      runtimeKey,
      entrypoint
    );
    checked.push(entrypointRelativePath);

    if (!isFile(path.join(platformRoot, entrypoint))) {
      missing.push(entrypointRelativePath);
    }

    requireFile(
      baseDir,
      runtimeKey,
      ['managed-resources', 'acp', toolId, version, runtimeKey, 'package.json'],
      checked,
      missing
    );
    requireFile(
      baseDir,
      runtimeKey,
      ['managed-resources', 'acp', toolId, version, runtimeKey, 'package-lock.json'],
      checked,
      missing
    );
    requireDirectory(
      baseDir,
      runtimeKey,
      ['managed-resources', 'acp', toolId, version, runtimeKey, 'node_modules'],
      checked,
      missing
    );

    const platformExecutableParts = acpToolPlatformExecutableParts(platform, runtimeKey, toolId);
    if (platformExecutableParts) {
      requireFile(
        baseDir,
        runtimeKey,
        ['managed-resources', 'acp', toolId, version, runtimeKey, ...platformExecutableParts],
        checked,
        missing
      );

      // Fallback: some prepared artifacts pack a different package layout
      // (e.g. @zed-industries/codex-acp-<runtimeKey>/bin/codex-acp.exe). If the
      // primary expected path is missing but a known alternative exists, accept it
      // and remove the earlier missing marker.
      if (toolId === 'codex-acp') {
        const expectedRelative = bundledPath(
          runtimeKey,
          'managed-resources',
          'acp',
          toolId,
          version,
          runtimeKey,
          ...platformExecutableParts
        );
        const altPath = path.join(
          baseDir,
          'managed-resources',
          'acp',
          toolId,
          version,
          runtimeKey,
          'node_modules',
          '@zed-industries',
          `codex-acp-${runtimeKey}`,
          'bin',
          process.platform === 'win32' ? 'codex-acp.exe' : 'codex-acp'
        );

        if (fs.existsSync(altPath) && fs.statSync(altPath).isFile()) {
          const altRelative = normalize(path.join('bundled-cora-cowork', runtimeKey, 'managed-resources', 'acp', toolId, version, runtimeKey, 'node_modules', '@zed-industries', `codex-acp-${runtimeKey}`, 'bin', path.basename(altPath)));
          checked.push(altRelative);
          // remove expectedRelative from missing if present
          const idx = missing.indexOf(expectedRelative);
          if (idx !== -1) missing.splice(idx, 1);
        }
      }
    }
  }
}

function verifyBundledCoraCoreResources({ resourcesDir, electronPlatformName, targetArch }) {
  const runtimeKey = `${electronPlatformName}-${targetArch}`;
  const baseDir = path.join(resourcesDir, 'bundled-cora-cowork', runtimeKey);
  const checked = [];
  const missing = [];

  function performChecks() {
    checked.length = 0;
    missing.length = 0;

    requireRelativePath(baseDir, runtimeKey, [backendBinaryName(electronPlatformName)], checked, missing);
    verifyBundleManifest(baseDir, runtimeKey, electronPlatformName, targetArch, checked, missing);
    requireRelativeDirectory(baseDir, runtimeKey, ['managed-resources'], checked, missing);
    requireManagedNode(baseDir, runtimeKey, electronPlatformName, checked, missing);
    requireManagedAcpTool(baseDir, runtimeKey, electronPlatformName, 'codex-acp', checked, missing);
    requireManagedAcpTool(baseDir, runtimeKey, electronPlatformName, 'claude-agent-acp', checked, missing);
  }

  performChecks();

  // If ACP tool artifacts are missing, try to download them from the managed ACP CDN
  // This helps local builds where artifacts were not prepared/uploaded yet.
  const MANAGED_ACP_CDN_BASE = process.env.MANAGED_ACP_CDN_BASE || 'https://coracowork.shop/managed/acp';

  function httpDownload(url, dest) {
    ensureDir(path.dirname(dest));
    try {
      if (process.platform === 'win32') {
        const ps = `$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '${url.replace(/'/g, "''")}' -OutFile '${dest.replace(/'/g, "''")}'`;
        execFileSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', ps], { stdio: 'inherit', timeout: 120000 });
      } else {
        execFileSync('curl', ['-L', '--fail', '--silent', '--show-error', '-o', dest, url], { stdio: 'inherit', timeout: 120000 });
      }
      return true;
    } catch (e) {
      try {
        // fallback to gh if available
        execFileSync('gh', ['api', url, '--output', dest], { stdio: 'inherit', timeout: 120000 });
        return true;
      } catch {
        return false;
      }
    }
  }

  function ensureDir(d) {
    if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });
  }

  function extractArchive(archivePath, outDir) {
    ensureDir(outDir);
    try {
      if (process.platform === 'win32' || archivePath.endsWith('.zip')) {
        if (process.platform === 'win32') {
          const ps = `Expand-Archive -LiteralPath '${archivePath.replace(/'/g, "''")}' -DestinationPath '${outDir.replace(/'/g, "''")}' -Force`;
          execFileSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', ps], { stdio: 'inherit' });
        } else {
          execFileSync('unzip', ['-o', archivePath, '-d', outDir], { stdio: 'inherit' });
        }
      } else if (archivePath.endsWith('.tar.zst') || archivePath.endsWith('.tar.gz') || archivePath.endsWith('.tgz')) {
        if (archivePath.endsWith('.tar.zst')) {
          execFileSync('zstd', ['-d', archivePath, '-c'], { stdio: ['ignore', 'pipe', 'inherit'] });
          // fall through to tar extraction not implemented here; prefer server-provided zip for Windows
        } else {
          execFileSync('tar', ['-xzf', archivePath, '-C', outDir], { stdio: 'inherit' });
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  function tryDownloadManagedAcpTool(toolId) {
    try {
      const rootManifestUrl = `${MANAGED_ACP_CDN_BASE}/manifest.json`;
      const tmp = path.join(os.tmpdir(), `managed-acp-${toolId}-${Date.now()}`);
      ensureDir(tmp);
      const rootManifestPath = path.join(tmp, 'root-manifest.json');
      if (!httpDownload(rootManifestUrl, rootManifestPath)) return false;
      const root = JSON.parse(fs.readFileSync(rootManifestPath, 'utf8'));
      const toolInfo = root.tools?.[toolId];
      if (!toolInfo || !toolInfo.version || !toolInfo.manifest_url) return false;
      const version = toolInfo.version;
      const versionManifestUrl = toolInfo.manifest_url;
      const versionManifestPath = path.join(tmp, 'version-manifest.json');
      if (!httpDownload(versionManifestUrl, versionManifestPath)) return false;
      const vmanifest = JSON.parse(fs.readFileSync(versionManifestPath, 'utf8'));
      const artifact = vmanifest.artifacts?.[runtimeKey];
      if (!artifact || !artifact.url) return false;
      const artifactUrl = artifact.url;
      const artifactFilename = path.basename(new URL(artifactUrl).pathname);
      const artifactPath = path.join(tmp, artifactFilename);
      if (!httpDownload(artifactUrl, artifactPath)) return false;

      const platformRoot = path.join(baseDir, 'managed-resources', 'acp', toolId, version, runtimeKey);
      // ensure parent and extract into a temp dir then move
      const extractDir = path.join(tmp, 'extract');
      ensureDir(extractDir);
      if (!extractArchive(artifactPath, extractDir)) return false;

      // The artifact packs the project root contents; copy them into platformRoot
      ensureDir(platformRoot);
      // Copy files
      const entries = fs.readdirSync(extractDir, { withFileTypes: true });
      for (const entry of entries) {
        const src = path.join(extractDir, entry.name);
        const dst = path.join(platformRoot, entry.name);
        if (entry.isDirectory()) {
          // recursive copy
          fs.cpSync(src, dst, { recursive: true, force: true });
        } else {
          ensureDir(path.dirname(dst));
          fs.copyFileSync(src, dst);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // If initial checks found missing ACP tool files, attempt to fetch them from CDN and re-run checks.
  const needsAcpDownload = missing.some((p) => p.includes('managed-resources/acp/'));
  if (needsAcpDownload) {
    let downloaded = false;
    if (missing.some((p) => p.includes('managed-resources/acp/codex-acp/'))) {
      console.log('   ⚠️  Missing codex-acp artifacts; attempting download from MANAGED_ACP_CDN_BASE');
      if (tryDownloadManagedAcpTool('codex-acp')) downloaded = true;
    }
    if (missing.some((p) => p.includes('managed-resources/acp/claude-agent-acp/'))) {
      console.log('   ⚠️  Missing claude-agent-acp artifacts; attempting download from MANAGED_ACP_CDN_BASE');
      if (tryDownloadManagedAcpTool('claude-agent-acp')) downloaded = true;
    }

    if (downloaded) {
      // re-run checks
      performChecks();
    }
  }

  return { runtimeKey, checked, missing };
}

module.exports = {
  verifyBundledCoraCoreResources,
};