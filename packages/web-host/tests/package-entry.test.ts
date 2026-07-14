import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

describe('web-host package entry metadata', () => {
  it('exports the built dist entrypoint for runtime consumption', () => {
    const packageJsonPath = resolve(__dirname, '../package.json');
    const pkg = JSON.parse(readFileSync(packageJsonPath, 'utf8')) as {
      main?: string;
      types?: string;
      exports?: Record<string, unknown>;
      scripts?: Record<string, string>;
    };

    expect(pkg.main).toBe('./dist/index.js');
    expect(pkg.types).toBe('./dist/index.d.ts');
    expect(pkg.scripts?.build).toBe('tsc -p tsconfig.json');

    const exportEntry = pkg.exports?.['.'];
    expect(exportEntry).toEqual({
      types: './dist/index.d.ts',
      import: './dist/index.js',
      default: './dist/index.js',
    });
  });
});
