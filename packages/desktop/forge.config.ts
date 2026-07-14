// packages/desktop/forge.config.ts
import type { ForgeConfig } from '@electron-forge/shared-types';

const config: ForgeConfig = {
  packagerConfig: {
    icon: './resources/app',  // Aponta para app.ico (Windows) ou app.icns (macOS)
    // ou
    // icon: './resources/logo',
  },
  rebuildConfig: {},
  makers: [
    {
      name: '@electron-forge/maker-squirrel',
      config: {
        name: 'CoraCowork',
        setupIcon: './resources/app.ico',  // Ícone do instalador
      },
    },
    {
      name: '@electron-forge/maker-zip',
      platforms: ['darwin', 'linux', 'win32'],
    },
  ],
};

export default config;