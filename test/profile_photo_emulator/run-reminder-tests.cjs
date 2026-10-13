const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname,'../..');
const command = `"${process.execPath}" --test "${path.join(__dirname,'reminder.rules.test.cjs')}"`;
const result=spawnSync(process.execPath,[require.resolve('firebase-tools/lib/bin/firebase'),
  'emulators:exec','--config','firebase.avatar-emulator.json','--only','firestore',
  '--project','demo-savetrack-reminders',command],{cwd:root,stdio:'inherit',env:{...process.env,CI:'true',
    FIREBASE_EMULATORS_PATH:path.join(root,'build/emulator')}});
if (result.error) throw result.error;
process.exit(result.status ?? 1);
