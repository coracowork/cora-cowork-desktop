/**
 * @license
 * Copyright 2026 CoraCowork (cora-cowork.com)
 * SPDX-License-Identifier: Apache-2.0
 */

export const GITHUB_OWNER = 'coracowork';
export const GITHUB_REPO = 'cora-cowork-desktop';

export type GitHubFeedOptions = {
  provider: 'github';
  owner: string;
  repo: string;
};

export function buildGitHubFeedOptions(): GitHubFeedOptions {
  return {
    provider: 'github',
    owner: GITHUB_OWNER,
    repo: GITHUB_REPO,
  };
}
