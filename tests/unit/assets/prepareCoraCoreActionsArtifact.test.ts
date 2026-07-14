import { describe, expect, it } from 'vitest';

const {
  getActionsArtifactName,
  getActionsArtifactMissingMessage,
} = require('../../../packages/shared-scripts/src/prepare-CoraCore');

describe('prepare-CoraCore GitHub Actions artifact resolver', () => {
  it.each([
    ['win32', 'x64', 'CoraCore-manual-windows-x64'],
    ['win32', 'arm64', 'CoraCore-manual-windows-arm64'],
    ['darwin', 'x64', 'CoraCore-manual-macos-x64'],
    ['darwin', 'arm64', 'CoraCore-manual-macos-arm64'],
    ['linux', 'x64', 'CoraCore-manual-linux-x64'],
    ['linux', 'arm64', 'CoraCore-manual-linux-arm64'],
  ])('maps %s-%s to %s', (platform, arch, artifactName) => {
    expect(getActionsArtifactName(platform, arch)).toBe(artifactName);
  });

  it('explains which CoraCore manual artifact is missing for the requested platform', () => {
    expect(
      getActionsArtifactMissingMessage({
        runId: '27319522909',
        platform: 'win32',
        arch: 'x64',
        expectedArtifactName: 'CoraCore-manual-windows-x64',
        availableArtifactNames: ['CoraCore-manual-macos-arm64', 'CoraCore-manual-linux-x64'],
      })
    ).toBe(
      [
        'CoraCore run 27319522909 does not contain artifact [ CoraCore-manual-windows-x64 ] required for [ win32-x64 ].',
        'Available artifacts: CoraCore-manual-macos-arm64, CoraCore-manual-linux-x64.',
        'Re-run CoraCore Manual Build with platform [ windows-x64 ] or all.',
      ].join(' ')
    );
  });
});

