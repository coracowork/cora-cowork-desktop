/**
 * Resolve the CoraCore version tag to download for packaging.
 *
 * Order:
 *   1. CORA_COWORK_BACKEND_VERSION env (ad-hoc override, e.g. CI dispatch input)
 *   2. "coraCoworkVersion" field in repo-root package.json (the pin)
 *   3. 'latest' (GitHub API releases/latest; non-reproducible fallback)
 *
 * Keep this file tiny and dependency-free — it's required from both
 * scripts/prepareCoracore.js and scripts/pack-web-cli.js before
 * any project-level install has necessarily completed.
 */

const fs = require('fs');
const path = require('path');

function resolveCoraCoworkVersion(projectRoot) {
  const envOverride = process.env.CORA_COWORK_BACKEND_VERSION;
  if (envOverride && envOverride.trim()) {
    return envOverride.trim();
  }

  try {
    const pkgPath = path.join(projectRoot, 'package.json');
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
    if (pkg && typeof pkg.coraCoworkVersion === 'string' && pkg.coraCoworkVersion.trim()) {
      return pkg.coraCoworkVersion.trim();
    }
    if (pkg && typeof pkg.coracoreVersion === 'string' && pkg.coracoreVersion.trim()) {
      return pkg.coracoreVersion.trim();
    }
  } catch {
    // fall through
  }

  return 'latest';
}

module.exports = { resolveCoraCoworkVersion };
