const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, deleteDoc, serverTimestamp, collection, getDocs } = require('firebase/firestore');

let env, alex, jamie, guest;
before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8089') throw new Error('Dedicated demo emulator required.');
  env = await initializeTestEnvironment({ projectId:'demo-savetrack-reminders', firestore: {
    host:'127.0.0.1',port:8089,rules:fs.readFileSync(path.resolve(__dirname,'../../firestore.rules'),'utf8'),
  }});
  alex = env.authenticatedContext('alex').firestore();
  jamie = env.authenticatedContext('jamie').firestore();
  guest = env.unauthenticatedContext().firestore();
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db,'users/alex/goals/fund'),{title:'Emergency Fund',savedAmount:1200,targetAmount:5000,currencyCode:'PHP'});
    await setDoc(doc(db,'users/alex/tasks/notes'),{title:'Review Notes',dateKey:'2026-10-14',time:'4:00 PM',priority:'High',completed:false});
    await setDoc(doc(db,'sharedGoals/trip'),{name:'Japan Vacation',memberIds:['alex','jamie'],status:'active',currentAmount:1200,targetAmount:5000});
    for (const uid of ['alex','jamie']) await setDoc(doc(db,`sharedGoals/trip/members/${uid}`),{status:'active'});
  });
});
function preference(uid='alex',type='personalGoal',targetId='fund',extra={}) {
  return {uid,type,targetId,enabled:true,hour:20,minute:0,frequency:'daily',instant:null,
    weekday:1,offsetMinutes:15,daysBefore:0,showTitle:false,version:1,updatedAt:serverTimestamp(),...extra};
}
const record = (db,uid='alex',type='personalGoal',id='fund') => doc(db,`users/${uid}/reminders/${type}_${id}`);

test('personal reminder writes only own preference, preserving financial data',async () => {
  const goal = doc(alex,'users/alex/goals/fund'); const before = (await getDoc(goal)).data();
  await assertSucceeds(setDoc(record(alex),preference()));
  await assertSucceeds(updateDoc(record(alex),{hour:21,updatedAt:serverTimestamp()}));
  assert.deepEqual((await getDoc(goal)).data(),before);
  assert.equal((await getDoc(record(alex))).data().hour,21);
});
test('guests and other accounts cannot read, list, create, update or delete preferences',async () => {
  await setDoc(record(alex),preference());
  for (const db of [guest,jamie]) {
    await assertFails(getDoc(record(db))); await assertFails(getDocs(collection(db,'users/alex/reminders')));
    await assertFails(setDoc(record(db),preference())); await assertFails(deleteDoc(record(db)));
  }
  await assertFails(setDoc(record(alex,'jamie','sharedGoal','trip'),preference('jamie','sharedGoal','trip')));
});
test('active shared members select independent times without changing shared balances',async () => {
  const goal = doc(alex,'sharedGoals/trip'); const before = (await getDoc(goal)).data();
  await assertSucceeds(setDoc(record(alex,'alex','sharedGoal','trip'),preference('alex','sharedGoal','trip')));
  await assertSucceeds(setDoc(record(jamie,'jamie','sharedGoal','trip'),preference('jamie','sharedGoal','trip',{hour:18,frequency:'weekly'})));
  assert.equal((await getDoc(record(alex,'alex','sharedGoal','trip'))).data().hour,20);
  assert.equal((await getDoc(record(jamie,'jamie','sharedGoal','trip'))).data().hour,18);
  assert.deepEqual((await getDoc(goal)).data(),before);
  await assertFails(updateDoc(record(alex,'jamie','sharedGoal','trip'),{hour:22,updatedAt:serverTimestamp()}));
});
test('revoked and inactive members cannot enable reminders but can disable and remove their own',async () => {
  const ref = record(jamie,'jamie','sharedGoal','trip');
  await setDoc(ref,preference('jamie','sharedGoal','trip'));
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(),'sharedGoals/trip'),{memberIds:['alex']});
    await updateDoc(doc(context.firestore(),'sharedGoals/trip/members/jamie'),{status:'removed'});
  });
  await assertFails(setDoc(ref,preference('jamie','sharedGoal','trip',{hour:19})));
  await assertSucceeds(setDoc(ref,preference('jamie','sharedGoal','trip',{enabled:false})));
  await assertSucceeds(deleteDoc(ref));
});
test('archived or deleted shared goals reject enabled reminders',async () => {
  await env.withSecurityRulesDisabled(async context => { await updateDoc(doc(context.firestore(),'sharedGoals/trip'),{status:'archived'}); });
  await assertFails(setDoc(record(alex,'alex','sharedGoal','trip'),preference('alex','sharedGoal','trip')));
  await env.withSecurityRulesDisabled(async context => { await deleteDoc(doc(context.firestore(),'sharedGoals/trip')); });
  await assertFails(setDoc(record(alex,'alex','sharedGoal','trip'),preference('alex','sharedGoal','trip')));
});
test('planner reminder offsets preserve priority, time, completion and all task data',async () => {
  const task = doc(alex,'users/alex/tasks/notes'); const before=(await getDoc(task)).data();
  await assertSucceeds(setDoc(record(alex,'alex','task','notes'),preference('alex','task','notes',{frequency:'taskStart'})));
  await assertSucceeds(setDoc(record(alex,'alex','task','notes'),preference('alex','task','notes',{
    frequency:'once',instant:'2026-10-14T07:45:00.000Z',hour:15,minute:45})));
  assert.deepEqual((await getDoc(task)).data(),before);
  await assertFails(setDoc(record(alex,'alex','task','notes'),preference('alex','task','notes',{frequency:'daily'})));
});
test('invalid schema, mismatched UID or ID, and missing targets are rejected',async () => {
  for (const extra of [{hour:24},{minute:60},{weekday:0},{offsetMinutes:2},{daysBefore:2},
    {showTitle:'yes'},{uid:'jamie'},{type:'unknown'},{targetId:'notes'},{instant:'bad'},{unexpected:'value'},
    {frequency:'once',instant:null},{frequency:'taskStart'}]) {
    await assertFails(setDoc(record(alex),preference('alex','personalGoal','fund',extra)));
  }
  await assertFails(setDoc(record(alex,'alex','personalGoal','missing'),preference('alex','personalGoal','missing')));
  await assertSucceeds(setDoc(record(alex,'alex','personalGoal','missing'),preference('alex','personalGoal','missing',{enabled:false})));
});
