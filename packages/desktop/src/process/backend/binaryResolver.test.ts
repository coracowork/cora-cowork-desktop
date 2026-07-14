import { execSync } from 'node:child_process';
import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { resolveBinaryPath } from './binaryResolver';

vi.mock('node:child_process', () => ({
  execSync: vi.fn(),
}));

vi.mock('node:fs', () => ({
  existsSync: vi.fn(),
  readdirSync: vi.fn(),
}));

const originalResourcesPath = (process as NodeJS.Process & { resourcesPath?: string }).resourcesPath;

function setResourcesPath(resourcesPath: string | undefined): void {
  Object.defineProperty(process, 'resourcesPath', {
    configurable: true,
    value: resourcesPath,
  });
}

function dirEntry(name: string, isDirectory = false): ReturnType<typeof readdirSync>[number] {
  return {
    name,
    isDirectory: () => isDirectory,
  } as unknown as ReturnType<typeof readdirSync>[number];
}

describe('resolveBinaryPath', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    setResourcesPath(originalResourcesPath);
  });

  it('attaches bundled path diagnostics when backend cannot be resolved', () => {
    const resourcesPath = '/app/resources';
    const runtimeKey = `${process.platform}-${process.arch}`;
    const binaryName = process.platform === 'win32' ? 'cora-cowork-app.exe' : 'cora-cowork-app';
    const bundledDir = join(resourcesPath, 'bundled-cora-cowork');
    const runtimeDir = join(bundledDir, runtimeKey);
    const checkedBundledPath = join(runtimeDir, binaryName);

    setResourcesPath(resourcesPath);
    vi.mocked(existsSync).mockReturnValue(false);
    vi.mocked(readdirSync).mockImplementation((path) => {
      if (path === resourcesPath) return [dirEntry('bundled-cora-cowork', true)];
      if (path === runtimeDir) return [dirEntry('manifest.json')];
      return [] as ReturnType<typeof readdirSync>;
    });
    vi.mocked(execSync).mockImplementation(() => {
      throw new Error('not found on PATH');
    });

    expect(() => resolveBinaryPath()).toThrow('Cannot find "cora-cowork-app" binary');

    try {
      resolveBinaryPath();
    } catch (error) {
      expect(error).toMatchObject({
        name: 'BackendBinaryResolveError',
        diagnostics: expect.objectContaining({
          resourcesPath,
          runtimeKey,
          binaryName,
          checkedBundledPath,
          bundledDirExists: false,
          runtimeDirExists: false,
          resourcesDirEntries: ['bundled-cora-cowork/'],
          runtimeDirEntries: ['manifest.json'],
          pathLookupCommand: process.platform === 'win32' ? 'where cora-cowork-app' : 'which cora-cowork-app',
          pathLookupError: expect.stringContaining('not found on PATH'),
        }),
      });
    }
  });

  it('resolves from project-level dev resources when bundled path misses', () => {
    // Simulate packaged resourcesPath (electron dist/resources — no backend here)
    const resourcesPath = '/app/node_modules/electron/dist/resources';
    setResourcesPath(resourcesPath);

    const runtimeKey = `${process.platform}-${process.arch}`;
    const binaryName = process.platform === 'win32' ? 'cora-cowork-app.exe' : 'cora-cowork-app';

    const existsMock = vi.mocked(existsSync);
    const readdirMock = vi.mocked(readdirSync);
    existsMock.mockImplementation((path) => {
      const p = String(path);
      // Only the project dev path has the binary
      if (p.endsWith(join('bundled-cora-cowork', runtimeKey, binaryName))) return true;
      // Project-level resources dir exists
      if (p.endsWith(join('resources'))) return true;
      return false;
    });
    readdirMock.mockReturnValue([]);

    const result = resolveBinaryPath();
    expect(result).toBeTruthy();
    // The project dev path candidate should end with the runtime dir + binary
    expect(result).toMatch(/bundled-cora-cowork[\\/]win/);
    expect(result).toMatch(/cora-cowork-app/);
  });

  it('prefers bundled (packaged) path over project-level dev path', () => {
    const resourcesPath = '/app/resources';
    setResourcesPath(resourcesPath);

    const runtimeKey = `${process.platform}-${process.arch}`;
    const binaryName = process.platform === 'win32' ? 'cora-cowork-app.exe' : 'cora-cowork-app';

    const existsMock = vi.mocked(existsSync);
    existsMock.mockReturnValue(true);
    vi.mocked(readdirSync).mockReturnValue([]);

    const result = resolveBinaryPath();
    expect(result).toBeTruthy();
    // Should contain the runtime dir + binary name (from packaged resourcesPath)
    expect(result).toContain(join('bundled-cora-cowork', runtimeKey, binaryName));
    // The first search (bundled) hits, so result should start with resourcesPath
    // Normalize both to forward slashes for comparison (Windows uses backslashes)
    expect(result.replace(/\\/g, '/')).toMatch(
      new RegExp(`^${resourcesPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\\/g, '/')}`)
    );
  });

  it('falls through to system PATH when both bundled and dev paths miss', () => {
    const resourcesPath = '/app/resources';
    setResourcesPath(resourcesPath);

    const systemPath = '/usr/local/bin/cora-cowork-app';
    const existsMock = vi.mocked(existsSync);
    existsMock.mockImplementation((path) => {
      // bundled and dev paths → not found, system path → found
      const p = String(path);
      if (p === systemPath) return true;
      return false;
    });
    vi.mocked(readdirSync).mockReturnValue([]);
    vi.mocked(execSync).mockReturnValue(systemPath);

    const result = resolveBinaryPath();
    expect(result).toBe(systemPath);
  });

  it('includes dev path diagnostics when resolution fails', () => {
    const resourcesPath = '/app/resources';
    setResourcesPath(resourcesPath);

    vi.mocked(existsSync).mockReturnValue(false);
    vi.mocked(readdirSync).mockReturnValue([]);
    vi.mocked(execSync).mockImplementation(() => {
      throw new Error('not found');
    });

    try {
      resolveBinaryPath();
    } catch (error) {
      expect(error).toMatchObject({
        name: 'BackendBinaryResolveError',
        diagnostics: expect.objectContaining({
          checkedDevPath: expect.stringContaining('bundled-cora-cowork'),
          devResourcesDirExists: false,
        }),
      });
    }
  });
});
