/**
 * @license
 * Copyright 2026 CoraCowork (coracowork.shop)
 * SPDX-License-Identifier: Apache-2.0
 */

import { getPlatformServices } from '@/common/platform';

/**
 * Returns baseName unchanged in release builds, or baseName + '-dev' in dev builds.
 * When CORA_COWORK_MULTI_INSTANCE=1, appends '-2' to isolate the second dev instance.
 * Used to isolate symlink and directory names between environments.
 *
 * @example
 * getEnvAwareName('.cora-cowork')        // release → '.cora-cowork',        dev → '.cora-cowork-dev'
 * getEnvAwareName('.cora-cowork-config') // release → '.cora-cowork-config', dev → '.cora-cowork-config-dev'
 * // with CORA_COWORK_MULTI_INSTANCE=1:  dev → '.cora-cowork-dev-2'
 */
export function getEnvAwareName(baseName: string): string {
  if (getPlatformServices().paths.isPackaged() === true) return baseName;
  const suffix = process.env.CORA_COWORK_MULTI_INSTANCE === '1' ? '-dev-2' : '-dev';
  return `${baseName}${suffix}`;
}
