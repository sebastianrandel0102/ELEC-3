const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, getBytes, deleteObject, listAll } = require('firebase/storage');
const { doc, setDoc, updateDoc, getDoc, deleteDoc, deleteField, serverTimestamp, Bytes, collection, getDocs } = require('firebase/firestore');

const projectId = 'demo-savetrack-avatar';
const gid = 'sharedGoalAAAAAAAAAA';
const version = 'AAAAAAAAAAAAAAAAAAAA';
const personal = `users/owner/goals/goalA/cover/${version}.jpg`;
const shared = `sharedGoals/${gid}/cover/${version}.jpg`;
const replacement = shared.replace(version, 'BBBBBBBBBBBBBBBBBBBB');
const bytes = Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]); // Rules enforce metadata; app tests decode actual JPEGs.
let env, owner, member, removed, other, guest;
before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8089' ||
      process.env.FIREBASE_STORAGE_EMULATOR_HOST !== '127.0.0.1:9197') throw new Error('Dedicated demo emulators required.');
  env = await initializeTestEnvironment({ projectId,
    firestore: { host: '127.0.0.1', port: 8089, rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8') },
    storage: { host: '127.0.0.1', port: 9197, rules: fs.readFileSync(path.resolve(__dirname, '../../storage.rules'), 'utf8') },
  });
  owner = env.authenticatedContext('owner'); member = env.authenticatedContext('member');
  removed = env.authenticatedContext('removed'); other = env.authenticatedContext('other'); guest = env.unauthenticatedContext();
});
beforeEach(async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    async function clear(folder) {
      const {items, prefixes} = await listAll(folder);
      await Promise.all([...items.map(deleteObject), ...prefixes.map(clear)]);
    }
    await clear(ref(ctx.storage()));
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'users/owner/goals/goalA'), { title: 'Travel', savedAmount: 123, targetAmount: 1000, currencyCode: 'PHP' });
    await setDoc(doc(ctx.firestore(), `sharedGoals/${gid}`), { ownerId: 'owner', memberIds: ['owner', 'member'], currentAmount: 50 });
    for (const uid of ['owner', 'member', 'removed']) await setDoc(doc(ctx.firestore(), `sharedGoals/${gid}/members/${uid}`),
      { role: uid === 'owner' ? 'owner' : 'contributor', status: uid === 'removed' ? 'removed' : 'active' });
  });
});
after(async () => { if (env) await env.cleanup(); });
const object = (ctx, name) => ref(ctx.storage(), name);
const upload = (ctx, name, data = bytes, contentType = 'image/jpeg') => uploadBytes(object(ctx, name), data, { contentType });
const personalDoc = ctx => doc(ctx.firestore(), 'users/owner/goals/goalA');
const sharedDoc = ctx => doc(ctx.firestore(), `sharedGoals/${gid}`);
const metadata = name => ({ coverStoragePath: name, coverUpdatedAt: serverTimestamp() });

test('personal owner uploads private immutable version and metadata survives new device', async () => {
  await assertSucceeds(upload(owner, personal));
  await assertSucceeds(updateDoc(personalDoc(owner), metadata(personal)));
  const device = env.authenticatedContext('owner');
  assert.equal((await getDoc(personalDoc(device))).data().coverStoragePath, personal);
  assert.deepEqual(new Uint8Array(await getBytes(object(device, personal))), bytes);
  await assertFails(upload(owner, personal));
  assert.equal((await getDoc(personalDoc(owner))).data().savedAmount, 123);
});
test('other users and guests cannot read, upload, delete or update personal covers', async () => {
  await upload(owner, personal);
  for (const ctx of [other, member, guest]) {
    await assertFails(getBytes(object(ctx, personal)));
    await assertFails(upload(ctx, personal.replace(version, 'BBBBBBBBBBBBBBBBBBBB')));
    await assertFails(deleteObject(object(ctx, personal)));
    await assertFails(updateDoc(personalDoc(ctx), metadata(personal)));
  }
});
test('cover path is goal-specific and cannot point to profile, other goal, owner or public URL', async () => {
  for (const name of ['users/owner/profile/avatar/AAAAAAAAAAAAAAAAAAAA.jpg', personal.replace('goalA', 'goalB'),
    personal.replace('owner', 'other'), shared, 'https://example.com/cover.jpg', 123]) {
    await assertFails(updateDoc(personalDoc(owner), metadata(name)));
  }
});
test('cover writes cannot change financial fields or currency', async () => {
  await assertFails(updateDoc(personalDoc(owner), {...metadata(personal), savedAmount: 500}));
  await assertFails(updateDoc(personalDoc(owner), {...metadata(personal), currencyCode: 'USD'}));
  await assertFails(updateDoc(sharedDoc(owner), {...metadata(shared), currentAmount: 900}));
  await assertFails(updateDoc(sharedDoc(owner), {...metadata(shared), memberIds: ['owner']}));
});
test('shared owner manages covers while active members only read confirmed cover', async () => {
  await assertSucceeds(upload(owner, shared));
  await assertFails(getBytes(object(member, shared))); // staging is private
  await assertSucceeds(updateDoc(sharedDoc(owner), metadata(shared)));
  assert.deepEqual(new Uint8Array(await getBytes(object(member, shared))), bytes);
  await assertFails(upload(member, replacement));
  await assertFails(updateDoc(sharedDoc(member), metadata(replacement)));
  await assertFails(updateDoc(sharedDoc(member), {coverStoragePath: deleteField(), coverUpdatedAt: serverTimestamp()}));
  await assertFails(deleteObject(object(member, shared)));
  await assertFails(listAll(ref(member.storage(), `sharedGoals/${gid}/cover`)));
});
test('removed, unrelated and unauthenticated users cannot fetch shared cover', async () => {
  await upload(owner, shared); await updateDoc(sharedDoc(owner), metadata(shared));
  for (const ctx of [removed, other, guest]) await assertFails(getBytes(object(ctx, shared)));
  await env.withSecurityRulesDisabled(async ctx => {
    await updateDoc(sharedDoc(ctx), {memberIds: ['owner']});
    await updateDoc(doc(ctx.firestore(), `sharedGoals/${gid}/members/member`), {status: 'removed'});
  });
  await assertFails(getBytes(object(member, shared)));
});
test('inactive membership is denied even if stale root memberIds includes user', async () => {
  await upload(owner, shared); await updateDoc(sharedDoc(owner), metadata(shared));
  await env.withSecurityRulesDisabled(async ctx => updateDoc(doc(ctx.firestore(), `sharedGoals/${gid}/members/member`), {status: 'left'}));
  await assertFails(getBytes(object(member, shared)));
});
test('referenced covers cannot be deleted; replacement exposes new version and permits old cleanup', async () => {
  await upload(owner, shared); await updateDoc(sharedDoc(owner), metadata(shared));
  await assertFails(deleteObject(object(owner, shared)));
  await upload(owner, replacement); await updateDoc(sharedDoc(owner), metadata(replacement));
  await assertSucceeds(getBytes(object(member, replacement)));
  await assertFails(getBytes(object(member, shared)));
  await assertSucceeds(deleteObject(object(owner, shared)));
  await assertFails(deleteObject(object(owner, replacement)));
});
test('remove cover clears only reference and allows image cleanup', async () => {
  await upload(owner, personal); await updateDoc(personalDoc(owner), metadata(personal));
  await assertFails(deleteObject(object(owner, personal)));
  await assertSucceeds(updateDoc(personalDoc(owner), {coverStoragePath: deleteField(), coverUpdatedAt: serverTimestamp()}));
  await assertSucceeds(deleteObject(object(owner, personal)));
  assert.equal((await getDoc(personalDoc(owner))).data().savedAmount, 123);
});
test('personal goal deletion revokes downloads but permits owner orphan cleanup', async () => {
  await upload(owner, personal); await updateDoc(personalDoc(owner), metadata(personal));
  await assertSucceeds(deleteDoc(personalDoc(owner)));
  await assertFails(getBytes(object(owner, personal)));
  await assertSucceeds(deleteObject(object(owner, personal)));
});
test('invalid filenames, unsupported MIME, empty and oversized uploads denied', async () => {
  for (const name of [personal.replace(`${version}.jpg`, 'bad.jpg'), personal.replace('.jpg', '.png')]) await assertFails(upload(owner, name));
  for (const type of ['image/png', 'image/webp', 'application/octet-stream', 'image/svg+xml']) await assertFails(upload(owner, personal, bytes, type));
  await assertFails(upload(owner, personal, new Uint8Array(0)));
  await assertFails(upload(owner, personal, new Uint8Array(1024 * 1024 + 1)));
  await assertFails(upload(owner, 'users/owner/goals/missing/cover/AAAAAAAAAAAAAAAAAAAA.jpg'));
});
test('journal is immutable, private and restricted to owner and correct goal path', async () => {
  const entry = doc(owner.firestore(), `users/owner/goalCoverUploads/${version}`);
  const record = {goalId: 'goalA', shared: false, storagePath: personal, createdAt: serverTimestamp()};
  await assertSucceeds(setDoc(entry, record));
  await assertFails(updateDoc(entry, {storagePath: shared}));
  await assertFails(getDoc(doc(other.firestore(), entry.path)));
  await assertFails(deleteDoc(doc(other.firestore(), entry.path)));
  const second = 'BBBBBBBBBBBBBBBBBBBB';
  await assertFails(setDoc(doc(owner.firestore(), `users/owner/goalCoverUploads/${second}`), {...record, storagePath: personal}));
  await assertSucceeds(setDoc(doc(owner.firestore(), `users/owner/goalCoverUploads/${second}`), {
    goalId: gid, shared: true, storagePath: replacement, createdAt: serverTimestamp()}));
  await assertFails(setDoc(doc(member.firestore(), `users/member/goalCoverUploads/${version}`), {
    goalId: gid, shared: true, storagePath: shared, createdAt: serverTimestamp()}));
});
test('profile avatar path remains isolated and unrelated storage paths stay denied', async () => {
  await assertSucceeds(upload(owner, 'users/owner/profile/avatar/AAAAAAAAAAAAAAAAAAAA.jpg'));
  await assertFails(upload(member, 'users/owner/profile/avatar/BBBBBBBBBBBBBBBBBBBB.jpg'));
  await assertFails(upload(owner, 'public/covers/AAAAAAAAAAAAAAAAAAAA.jpg'));
});

const personalPhoto = `users/owner/goals/goalA/coverPhotos/${version}`;
const sharedPhoto = `sharedGoals/${gid}/coverPhotos/${version}`;
const photo = (overrides = {}) => ({
  bytes: Bytes.fromUint8Array(Uint8Array.from([0xff, 0xd8, 0xff, 0xe0, 0xff, 0xd9])),
  contentType: 'image/jpeg', width: 960, height: 540, createdAt: serverTimestamp(), ...overrides,
});
const putPhoto = (ctx, name, values = photo()) => setDoc(doc(ctx.firestore(), name), values);
const getPhoto = (ctx, name) => getDoc(doc(ctx.firestore(), name));
const deletePhoto = (ctx, name) => deleteDoc(doc(ctx.firestore(), name));

test('compact personal Firestore covers persist privately on another owner device without Storage', async () => {
  await assertSucceeds(putPhoto(owner, personalPhoto));
  await assertSucceeds(updateDoc(personalDoc(owner), metadata(personalPhoto)));
  const device = env.authenticatedContext('owner');
  assert.equal((await getDoc(personalDoc(device))).data().coverStoragePath, personalPhoto);
  assert.equal((await getPhoto(device, personalPhoto)).data().width, 960);
  assert.equal((await getDoc(personalDoc(owner))).data().savedAmount, 123);
  await assertFails(putPhoto(owner, personalPhoto));
  await assertFails(getDocs(collection(owner.firestore(), 'users/owner/goals/goalA/coverPhotos')));
});

test('Firestore personal cover access is denied to other users and guests', async () => {
  await putPhoto(owner, personalPhoto);
  for (const ctx of [other, member, guest]) {
    await assertFails(getPhoto(ctx, personalPhoto));
    await assertFails(putPhoto(ctx, personalPhoto.replace(version, 'BBBBBBBBBBBBBBBBBBBB')));
    await assertFails(deletePhoto(ctx, personalPhoto));
    await assertFails(updateDoc(personalDoc(ctx), metadata(personalPhoto)));
  }
});

test('Firestore references require an existing goal-specific immutable photo', async () => {
  await assertFails(updateDoc(personalDoc(owner), metadata(personalPhoto)));
  await assertFails(updateDoc(sharedDoc(owner), metadata(sharedPhoto)));
  await putPhoto(owner, personalPhoto);
  for (const name of [personalPhoto.replace('goalA', 'goalB'), personalPhoto.replace('/owner/', '/other/'),
    sharedPhoto, 'users/owner/profilePhotos/AAAAAAAAAAAAAAAAAAAA', 'https://example.com/coverPhotos/AAAAAAAAAAAAAAAAAAAA']) {
    await assertFails(updateDoc(personalDoc(owner), metadata(name)));
  }
  await assertSucceeds(updateDoc(personalDoc(owner), metadata(personalPhoto)));
});

test('Firestore shared members read only the confirmed cover while its owner manages photos', async () => {
  await assertSucceeds(putPhoto(owner, sharedPhoto));
  await assertFails(getPhoto(member, sharedPhoto));
  await assertSucceeds(updateDoc(sharedDoc(owner), metadata(sharedPhoto)));
  await assertSucceeds(getPhoto(member, sharedPhoto));
  const next = sharedPhoto.replace(version, 'BBBBBBBBBBBBBBBBBBBB');
  await assertFails(putPhoto(member, next));
  await assertFails(updateDoc(sharedDoc(member), metadata(next)));
  await assertFails(deletePhoto(member, sharedPhoto));
  await assertFails(getDocs(collection(member.firestore(), `sharedGoals/${gid}/coverPhotos`)));
});

test('Firestore shared covers reject unrelated, removed, signed-out and inactive members', async () => {
  await putPhoto(owner, sharedPhoto);
  await updateDoc(sharedDoc(owner), metadata(sharedPhoto));
  for (const ctx of [other, removed, guest]) await assertFails(getPhoto(ctx, sharedPhoto));
  await env.withSecurityRulesDisabled(async ctx => updateDoc(doc(ctx.firestore(), `sharedGoals/${gid}/members/member`), {status: 'left'}));
  await assertFails(getPhoto(member, sharedPhoto));
  await env.withSecurityRulesDisabled(async ctx => {
    await updateDoc(doc(ctx.firestore(), `sharedGoals/${gid}/members/member`), {status: 'active'});
    await updateDoc(sharedDoc(ctx), {memberIds: ['owner']});
  });
  await assertFails(getPhoto(member, sharedPhoto));
});

test('Firestore replacement protects current photos and revokes shared reads of the obsolete version', async () => {
  const next = sharedPhoto.replace(version, 'BBBBBBBBBBBBBBBBBBBB');
  await putPhoto(owner, sharedPhoto); await updateDoc(sharedDoc(owner), metadata(sharedPhoto));
  await assertFails(deletePhoto(owner, sharedPhoto));
  await putPhoto(owner, next); await updateDoc(sharedDoc(owner), metadata(next));
  await assertFails(getPhoto(member, sharedPhoto));
  await assertSucceeds(getPhoto(member, next));
  await assertSucceeds(deletePhoto(owner, sharedPhoto));
  await assertFails(deletePhoto(owner, next));
});

test('Firestore cover removal and parent deletion permit only owner cleanup', async () => {
  await putPhoto(owner, personalPhoto); await updateDoc(personalDoc(owner), metadata(personalPhoto));
  await assertFails(deletePhoto(owner, personalPhoto));
  await updateDoc(personalDoc(owner), {coverStoragePath: deleteField(), coverUpdatedAt: serverTimestamp()});
  await assertSucceeds(deletePhoto(owner, personalPhoto));
  await putPhoto(owner, personalPhoto); await updateDoc(personalDoc(owner), metadata(personalPhoto));
  await deleteDoc(personalDoc(owner));
  await assertFails(getPhoto(owner, personalPhoto));
  await assertFails(deletePhoto(other, personalPhoto));
  await assertSucceeds(deletePhoto(owner, personalPhoto));
});

test('Firestore covers reject invalid blob, dimensions, type, size, timestamps and extra fields', async () => {
  for (const overrides of [{bytes: Bytes.fromUint8Array(new Uint8Array(0))},
    {bytes: Bytes.fromUint8Array(new Uint8Array(200 * 1024 + 1))}, {bytes: 'not binary'},
    {bytes: Bytes.fromUint8Array(Uint8Array.from([0, 1, 2]))}, {width: 1280}, {height: 720},
    {contentType: 'image/png'}, {createdAt: new Date(0)}, {downloadUrl: 'https://example.com'}]) {
    await assertFails(putPhoto(owner, personalPhoto, photo(overrides)));
  }
  await assertFails(putPhoto(owner, personalPhoto.replace(version, 'bad')));
  await assertFails(putPhoto(owner, personalPhoto.replace('goalA', 'missing')));
  await assertFails(putPhoto(owner, sharedPhoto.replace(gid, 'missing')));
});

test('a compact photo at the exact 200 KiB boundary can be stored and attached', async () => {
  const data = new Uint8Array(200 * 1024);
  data.set([0xff, 0xd8, 0xff, 0xe0]);
  data.set([0xff, 0xd9], data.length - 2);
  await assertSucceeds(putPhoto(owner, personalPhoto, photo({bytes: Bytes.fromUint8Array(data)})));
  await assertSucceeds(updateDoc(personalDoc(owner), metadata(personalPhoto)));
  assert.equal((await getPhoto(owner, personalPhoto)).data().bytes.toUint8Array().length, data.length);
});

test('Firestore cover metadata cannot be combined with financial or membership changes', async () => {
  await putPhoto(owner, personalPhoto); await putPhoto(owner, sharedPhoto);
  await assertFails(updateDoc(personalDoc(owner), {...metadata(personalPhoto), savedAmount: 500}));
  await assertFails(updateDoc(personalDoc(owner), {...metadata(personalPhoto), currencyCode: 'USD'}));
  await assertFails(updateDoc(sharedDoc(owner), {...metadata(sharedPhoto), currentAmount: 900}));
  await assertFails(updateDoc(sharedDoc(owner), {...metadata(sharedPhoto), memberIds: ['owner']}));
});

test('Firestore cover journals accept the exact compact path and remain private and immutable', async () => {
  const entry = doc(owner.firestore(), `users/owner/goalCoverUploads/${version}`);
  await assertSucceeds(setDoc(entry, {goalId: 'goalA', shared: false, storagePath: personalPhoto, createdAt: serverTimestamp()}));
  await assertFails(updateDoc(entry, {storagePath: sharedPhoto}));
  await assertFails(getDoc(doc(other.firestore(), entry.path)));
  await assertFails(setDoc(doc(member.firestore(), `users/member/goalCoverUploads/${version}`), {
    goalId: gid, shared: true, storagePath: sharedPhoto, createdAt: serverTimestamp()}));
  await assertFails(setDoc(doc(owner.firestore(), 'users/owner/goalCoverUploads/BBBBBBBBBBBBBBBBBBBB'), {
    goalId: 'goalA', shared: false, storagePath: personalPhoto, createdAt: serverTimestamp()}));
});
