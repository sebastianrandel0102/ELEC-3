const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '../..');
const testFile = path.join(__dirname, 'profile-photo.rules.test.cjs');
const command = `"${process.execPath}" --test "${testFile}"`;
const result = spawnSync(process.execPath, [require.resolve('firebase-tools/lib/bin/firebase'),
  'emulators:exec', '--config', 'firebase.avatar-emulator.json', '--only', 'firestore,storage',
  '--project', 'demo-savetrack-avatar', command], {
  cwd: root, stdio: 'inherit', env: { ...process.env, CI: 'true',
    FIREBASE_EMULATORS_PATH: process.env.FIREBASE_EMULATORS_PATH || path.join(root, 'build/emulator') },
});
if (result.error) throw result.error;
process.exit(result.status ?? 1);
