/**
 * CLI wrapper for prepare-cora-cowork.
 *
 * Reads environment variables and invokes the shared module.
 *
 * Version resolution order:
 *  1. CORA_COWORK_BACKEND_RUN_ID env (download from CoraCore Manual Build artifact)
 *  2. CORA_COWORK_BACKEND_VERSION env (for ad-hoc release overrides)
 *  3. "coraCoworkVersion" field in repo-root package.json (the pin)
 *  4. 'latest' (fallback; not recommended for reproducible builds)
 *
 * Environment variables:
 *  - CORA_COWORK_BACKEND_RUN_ID: CoraCore Manual Build workflow run id
 *  - CORA_COWORK_BACKEND_VERSION: override the pinned version
 *  - CORA_COWORK_BACKEND_ARCH: target architecture (default: process.arch)
 *  - GH_TOKEN / GITHUB_TOKEN: GitHub API token (for rate limiting)
 */

const path = require('path');
const { prepareCoracore } = require('../packages/shared-scripts/src/prepare-cora-cowork.js');
const { resolveCoraCoworkVersion } = require('./resolveCoraCoworkVersion.js');

const projectRoot = path.resolve(__dirname, '..');
const platform = process.platform;
// Support cross-compilation: CORA_COWORK_BACKEND_ARCH > npm_config_target_arch > process.arch
const arch = process.env.CORA_COWORK_BACKEND_ARCH || process.env.npm_config_target_arch || process.arch;
const version = resolveCoraCoworkVersion(projectRoot);

try {
  prepareCoracore({ projectRoot, platform, arch, version });
} catch (error) {
  console.error('❌ prepareCoracore failed:', error.message);
  process.exit(1);
}

module.exports = function () {
  try {
    return prepareCoracore({ projectRoot, platform, arch, version });
  } catch (error) {
    console.error('❌ prepareCoracore failed:', error.message);
    throw error;
  }
};
