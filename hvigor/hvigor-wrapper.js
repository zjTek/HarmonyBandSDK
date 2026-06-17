'use strict';

const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');
process.chdir(projectRoot);

function resolveHvigorEntry() {
  const candidates = [
    path.join(projectRoot, 'oh_modules', '@ohos', 'hvigor', 'bin', 'hvigor.js'),
    path.join(projectRoot, 'node_modules', '@ohos', 'hvigor', 'bin', 'hvigor.js'),
    '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js'
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return '';
}

const hvigorEntry = resolveHvigorEntry();
if (!hvigorEntry) {
  console.error('[HVIGOR] Hvigor is not initialized.');
  console.error('[HVIGOR] Open this project in DevEco Studio and click Sync Now.');
  process.exit(1);
}

require(hvigorEntry);
