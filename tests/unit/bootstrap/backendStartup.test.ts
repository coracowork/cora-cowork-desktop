/**
 * @license
 * Copyright 2025 CoraCowork (coracowork.com)
 * SPDX-License-Identifier: Apache-2.0
 */

import { describe, expect, it, vi, afterEach } from 'vitest';

vi.mock('fs', () => ({
  existsSync: vi.fn(),
  readdirSync: vi.fn(),
  readFileSync: vi.fn(),
  Dirent: class {
    constructor(public name: string, private isDir: boolean) {}
    isDirectory() {
      return this.isDir;
    }
    isFile() {
      return !this.isDir;
    }
  },
}));

import * as fs from 'fs';
import * as path from 'path';
import { startBackendOrExit } from '@/process/startup/backendStartup';

afterEach(() => {
  vi.restoreAllMocks();
});

describe('startBackendOrExit', () => {
  it('registers the backend port when startup succeeds', async () => {
    const onStarted = vi.fn();
    const captureFailure = vi.fn();
    const exitApp = vi.fn();

    const result = await startBackendOrExit({
      startBackend: async () => 42123,
      onStarted,
      captureFailure,
      exitApp,
      logError: vi.fn(),
    });

    expect(result).toEqual({ ok: true, port: 42123 });
    expect(onStarted).toHaveBeenCalledWith(42123);
    expect(captureFailure).not.toHaveBeenCalled();
    expect(exitApp).not.toHaveBeenCalled();
  });

  it('captures startup failure and exits without registering a backend port by default', async () => {
    const error = new Error('CoraCore failed to start within timeout');
    const calls: string[] = [];
    const onStarted = vi.fn();
    const captureFailure = vi.fn(async () => {
      calls.push('capture-start');
      await Promise.resolve();
      calls.push('capture-end');
    });
    const exitApp = vi.fn(() => {
      calls.push('exit');
    });
    const logError = vi.fn();

    const result = await startBackendOrExit({
      startBackend: async () => {
        throw error;
      },
      onStarted,
      captureFailure,
      exitApp,
      logError,
    });

    expect(result).toEqual({ ok: false });
    expect(logError).toHaveBeenCalledWith('[CoraCowork] Failed to start CoraCore:', error);
    expect(captureFailure).toHaveBeenCalledWith(error);
    expect(exitApp).toHaveBeenCalledWith(1);
    expect(calls).toEqual(['capture-start', 'capture-end', 'exit']);
    expect(onStarted).not.toHaveBeenCalled();
  });

  it('captures startup failure without dialog or exit when exitOnFailure is disabled', async () => {
    const error = new Error('CoraCore exited before health check passed');
    const onStarted = vi.fn();
    const captureFailure = vi.fn();
    const exitApp = vi.fn();
    const logError = vi.fn();

    const result = await startBackendOrExit({
      startBackend: async () => {
        throw error;
      },
      onStarted,
      captureFailure,
      exitApp,
      exitOnFailure: false,
      logError,
    });

    expect(result).toEqual({ ok: false });
    expect(logError).toHaveBeenCalledWith('[CoraCowork] Failed to start CoraCore:', error);
    expect(captureFailure).toHaveBeenCalledWith(error);
    expect(exitApp).not.toHaveBeenCalled();
    expect(onStarted).not.toHaveBeenCalled();
  });

  it('does not capture or exit when backend startup is cancelled by shutdown', async () => {
    const error = new Error('CoraCore startup cancelled');
    error.name = 'BackendStartupCancelledError';
    const onStarted = vi.fn();
    const captureFailure = vi.fn();
    const exitApp = vi.fn();
    const logError = vi.fn();

    const result = await startBackendOrExit({
      startBackend: async () => {
        throw error;
      },
      onStarted,
      captureFailure,
      exitApp,
      logError,
    });

    expect(result).toEqual({ ok: false });
    expect(logError).not.toHaveBeenCalled();
    expect(captureFailure).not.toHaveBeenCalled();
    expect(exitApp).not.toHaveBeenCalled();
    expect(onStarted).not.toHaveBeenCalled();
  });

  it('recovers backend port from a nested log file path', async () => {
    const onStarted = vi.fn();
    const captureFailure = vi.fn();
    const exitApp = vi.fn();
    const logError = vi.fn();
    const rootDir = path.join('/var', 'logs');
    const nestedFile = path.join(rootDir, '2026', '07', '10', '2026-07-10.log');

    const fsMock = fs as unknown as {
      existsSync: { mockReturnValue: (value: boolean) => void };
      readdirSync: { mockImplementation: (impl: (dir: fs.PathLike, options?: any) => any) => void };
      readFileSync: { mockImplementation: (impl: (filePath: fs.PathLike, encoding: any) => string) => void };
    };
    fsMock.existsSync.mockReturnValue(true);
    fsMock.readdirSync.mockImplementation((dir: fs.PathLike, options?: any) => {
      if (dir === rootDir) {
        return [{ name: '2026', isDirectory: () => true, isFile: () => false }];
      }
      if (dir === path.join(rootDir, '2026')) {
        return [{ name: '07', isDirectory: () => true, isFile: () => false }];
      }
      if (dir === path.join(rootDir, '2026', '07')) {
        return [{ name: '10', isDirectory: () => true, isFile: () => false }];
      }
      if (dir === path.join(rootDir, '2026', '07', '10')) {
        return [{ name: '2026-07-10.log', isDirectory: () => false, isFile: () => true }];
      }
      return [];
    });
    fsMock.readFileSync.mockImplementation((filePath: fs.PathLike, encoding: any) => {
      if (String(filePath) === nestedFile) {
        return 'CoraCore_LISTENING {"host":"127.0.0.1","port":55555}\n';
      }
      return '';
    });

    const result = await startBackendOrExit({
      startBackend: async () => {
        throw new Error('backend startup failed');
      },
      onStarted,
      captureFailure,
      exitApp,
      logError,
      logDir: rootDir,
      exitOnFailure: false,
    });

    expect(result).toEqual({ ok: true, port: 55555 });
    expect(onStarted).toHaveBeenCalledWith(55555);
    expect(captureFailure).not.toHaveBeenCalled();
    expect(exitApp).not.toHaveBeenCalled();
  });
});


