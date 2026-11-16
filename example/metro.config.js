const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

// The example consumes the package from the parent folder (file:..), so Metro must watch it
// and must resolve react / react-native from this app only, never from a second copy.
const root = path.resolve(__dirname, '..');

/** @type {import('@react-native/metro-config').MetroConfig} */
const config = {
  watchFolders: [root],
  resolver: {
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
    extraNodeModules: {
      'react-native-revechat': root,
      react: path.resolve(__dirname, 'node_modules/react'),
      'react-native': path.resolve(__dirname, 'node_modules/react-native'),
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
