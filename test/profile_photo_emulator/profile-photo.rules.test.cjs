const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, getBytes, getMetadata, deleteObject, listAll } = require('firebase/storage');
const { doc, setDoc, updateDoc, getDoc, deleteDoc, deleteField, Bytes,
  serverTimestamp, collection, query, where, documentId, getDocs } = require('firebase/firestore');

// All access uses demo emulators. There is no production project configuration.
const projectId = 'demo-savetrack-avatar';
const avatar = 'users/owner/profile/avatar/AAAAAAAAAAAAAAAAAAAA.jpg';
const replacement = 'users/owner/profile/avatar/BBBBBBBBBBBBBBBBBBBB.jpg';
const jpeg = Uint8Array.from(Buffer.from(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABAf/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPxB//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPxB//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxB//9k=', 'base64'));
let environment;
let owner, other, guest;

before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8089' ||
      process.env.FIREBASE_STORAGE_EMULATOR_HOST !== '127.0.0.1:9197') {
    throw new Error('Refusing to test outside the dedicated local emulators.');
  }
  environment = await initializeTestEnvironment({ projectId,
    firestore: { host: '127.0.0.1', port: 8089,
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8') },
    storage: { host: '127.0.0.1', port: 9197,
      rules: fs.readFileSync(path.resolve(__dirname, '../../storage.rules'), 'utf8') },
  });
  owner = environment.authenticatedContext('owner');
  other = environment.authenticatedContext('other');
  guest = environment.unauthenticatedContext();
});
beforeEach(async () => {
  // rules-unit-testing's clearStorage only deletes objects at the bucket root.
  // Avatar objects are nested, so recursively reset this demo bucket explicitly.
  await environment.withSecurityRulesDisabled(async (context) => {
    async function clearFolder(folder) {
      const { items, prefixes } = await listAll(folder);
      await Promise.all([...items.map(deleteObject), ...prefixes.map(clearFolder)]);
    }
    await clearFolder(ref(context.storage()));
  });
  await environment.clearFirestore();
});
after(async () => { if (environment) await environment.cleanup(); });

const object = (context, name = avatar) => ref(context.storage(), name);
const upload = (context = owner, name = avatar, bytes = jpeg, contentType = 'image/jpeg') =>
  uploadBytes(object(context, name), bytes, { contentType });

test('owner can upload and download exact bytes; profile reference survives a new context', async () => {
  await assertSucceeds(upload());
  const bytes = new Uint8Array(await getBytes(object(owner)));
  assert.deepEqual(bytes, jpeg);
  const profile = doc(owner.firestore(), 'users/owner');
  await assertSucceeds(setDoc(profile, { displayName: 'Jamie', currency: 'PHP',
    preferredCurrencyCode: 'USD', avatarStoragePath: avatar, avatarCleanupPaths: [] }));
  const restored = environment.authenticatedContext('owner');
  assert.equal((await getDoc(doc(restored.firestore(), 'users/owner'))).data().avatarStoragePath, avatar);
  assert.deepEqual(new Uint8Array(await getBytes(object(restored))), jpeg);
});
test('guest cannot upload, read, list or delete avatars', async () => {
  await upload();
  await assertFails(upload(guest, replacement));
  await assertFails(getMetadata(object(guest)));
  await assertFails(listAll(ref(guest.storage(), 'users/owner/profile/avatar')));
  await assertFails(deleteObject(object(guest)));
});
test('another account cannot upload, overwrite, read, list or delete owner avatar', async () => {
  await upload();
  await assertFails(upload(other, replacement));
  await assertFails(upload(other));
  await assertFails(getBytes(object(other)));
  await assertFails(listAll(ref(other.storage(), 'users/owner/profile/avatar')));
  await assertFails(deleteObject(object(other)));
});
test('owner can list and delete own avatar; objects cannot be overwritten', async () => {
  await upload();
  await assertSucceeds(listAll(ref(owner.storage(), 'users/owner/profile/avatar')));
  await assertFails(upload());
  await assertSucceeds(deleteObject(object(owner)));
});
test('unsupported content types and invalid filenames are rejected', async () => {
  for (const contentType of ['application/octet-stream', 'application/x-msdownload', 'image/png', 'image/svg+xml']) {
    await assertFails(upload(owner, avatar, jpeg, contentType));
  }
  await assertFails(upload(owner, 'users/owner/profile/avatar/unsafe.exe'));
  await assertFails(upload(owner, 'users/owner/profile/avatar/photo.jpg'));
});
test('empty and oversized uploads are rejected', async () => {
  await assertFails(upload(owner, avatar, new Uint8Array(0)));
  await assertFails(upload(owner, avatar, new Uint8Array(5 * 1024 * 1024 + 1)));
});
test('unrelated storage paths remain inaccessible', async () => {
  await assertFails(upload(owner, 'users/owner/receipts/AAAAAAAAAAAAAAAAAAAA.jpg'));
  await assertFails(upload(owner, 'public/AAAAAAAAAAAAAAAAAAAA.jpg'));
});
test('foreign or invalid profile references and excessive cleanup queues are rejected', async () => {
  const profile = doc(owner.firestore(), 'users/owner');
  await setDoc(profile, { preferredCurrencyCode: 'PHP' });
  for (const avatarStoragePath of ['https://example.com/photo.jpg',
    'users/other/profile/avatar/AAAAAAAAAAAAAAAAAAAA.jpg', 'users/owner/profile/avatar/unsafe.jpg']) {
    await assertFails(updateDoc(profile, { avatarStoragePath }));
  }
  await assertFails(updateDoc(profile, { avatarCleanupPaths: Array(101).fill(avatar) }));
  await assertFails(updateDoc(doc(other.firestore(), 'users/owner'), { avatarStoragePath: avatar }));
});
test('replace and remove update only profile metadata, preserving savings and planner records', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/owner'), { displayName: 'Jamie Santos',
      email: 'jamie@example.com', currency: 'PHP', preferredCurrencyCode: 'USD',
      notificationsEnabled: true, avatarStoragePath: avatar });
    await setDoc(doc(context.firestore(), 'users/owner/goals/emergency'), { savedAmount: 1200, targetAmount: 5000 });
    await setDoc(doc(context.firestore(), 'users/owner/tasks/today'), { title: 'Keep this task', completed: false });
  });
  await upload();
  await upload(owner, replacement);
  const profile = doc(owner.firestore(), 'users/owner');
  await assertSucceeds(updateDoc(profile, { avatarStoragePath: replacement, avatarCleanupPaths: [avatar] }));
  await deleteObject(object(owner, avatar));
  await assertSucceeds(updateDoc(profile, { avatarStoragePath: deleteField(), avatarCleanupPaths: [replacement] }));
  await deleteObject(object(owner, replacement));
  const data = (await getDoc(profile)).data();
  assert.equal(data.avatarStoragePath, undefined);
  assert.equal(data.displayName, 'Jamie Santos');
  assert.equal(data.preferredCurrencyCode, 'USD');
  assert.equal(data.notificationsEnabled, true);
  assert.equal((await getDoc(doc(owner.firestore(), 'users/owner/goals/emergency'))).data().savedAmount, 1200);
  assert.equal((await getDoc(doc(owner.firestore(), 'users/owner/tasks/today'))).data().title, 'Keep this task');
});

const firestoreAvatar = 'users/owner/profilePhotos/AAAAAAAAAAAAAAAAAAAA';
const firestoreReplacement = 'users/owner/profilePhotos/BBBBBBBBBBBBBBBBBBBB';
const photoData = (bytes = jpeg) => ({ bytes: Bytes.fromUint8Array(bytes),
  contentType: 'image/jpeg', width: 512, height: 512, createdAt: serverTimestamp() });
const savePhoto = (context = owner, name = firestoreAvatar, data = photoData()) =>
  setDoc(doc(context.firestore(), name), data);

test('Spark avatar bytes and profile reference persist across authenticated sessions', async () => {
  await assertSucceeds(savePhoto());
  await assertSucceeds(setDoc(doc(owner.firestore(), 'users/owner'), {
    displayName: 'Jamie', preferredCurrencyCode: 'PHP',
    avatarStoragePath: firestoreAvatar, avatarCleanupPaths: [],
  }));
  const restored = environment.authenticatedContext('owner');
  const data = (await getDoc(doc(restored.firestore(), firestoreAvatar))).data();
  assert.deepEqual(data.bytes.toUint8Array(), jpeg);
  assert.equal(data.contentType, 'image/jpeg');
  assert.equal((await getDoc(doc(restored.firestore(), 'users/owner'))).data().avatarStoragePath, firestoreAvatar);
});
test('Spark avatars deny unauthenticated and foreign read, write, list and delete', async () => {
  await savePhoto();
  for (const context of [guest, other]) {
    await assertFails(getDoc(doc(context.firestore(), firestoreAvatar)));
    await assertFails(savePhoto(context, firestoreReplacement));
    await assertFails(updateDoc(doc(context.firestore(), firestoreAvatar), { width: 1 }));
    await assertFails(getDocs(collection(context.firestore(), 'users/owner/profilePhotos')));
    await assertFails(deleteDoc(doc(context.firestore(), firestoreAvatar)));
  }
});
test('Spark avatars enforce binary type, JPEG signature, dimensions, size and field allowlist', async () => {
  for (const data of [
    { ...photoData(), bytes: 'executable data' },
    photoData(new Uint8Array(0)),
    photoData(Uint8Array.from([77,90,0,0])),
    { ...photoData(), contentType: 'image/png' },
    { ...photoData(), width: 4096 },
    { ...photoData(), height: 4096 },
    { ...photoData(), secret: 'unexpected field' },
    photoData(new Uint8Array(200 * 1024 + 1)),
    { ...photoData(), createdAt: new Date(2000, 0, 1) },
  ]) await assertFails(savePhoto(owner, firestoreAvatar, data));
  await assertFails(savePhoto(owner, 'users/owner/profilePhotos/unsafe-id'));
  // Exercise the maximum byte payload in the rules runtime, including the
  // framing check's conversion to hex. Full decoding is enforced by Flutter.
  const atLimit = new Uint8Array(200 * 1024);
  atLimit.set([255, 216, 255]);
  atLimit.set([255, 217], atLimit.length - 2);
  await assertSucceeds(savePhoto(owner, firestoreAvatar, photoData(atLimit)));
  await assertFails(savePhoto()); // immutable object
});
test('profile references cannot point at missing or foreign Spark avatar documents', async () => {
  const profile = doc(owner.firestore(), 'users/owner');
  await setDoc(profile, { preferredCurrencyCode: 'PHP' });
  await assertFails(updateDoc(profile, { avatarStoragePath: firestoreAvatar }));
  await savePhoto();
  await assertSucceeds(updateDoc(profile, { avatarStoragePath: firestoreAvatar }));
  await assertFails(updateDoc(profile, {
    avatarStoragePath: 'users/other/profilePhotos/AAAAAAAAAAAAAAAAAAAA',
  }));
});
test('Spark replacement/removal protect the active photo and preserve unrelated user data', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/owner'), { displayName: 'Jamie', email: 'private@example.com',
      currency: 'PHP', preferredCurrencyCode: 'USD', notificationsEnabled: true });
    await setDoc(doc(context.firestore(), 'users/owner/goals/keep'), { savedAmount: 1000 });
    await setDoc(doc(context.firestore(), 'users/owner/tasks/keep'), { title: 'Keep me' });
  });
  const profile = doc(owner.firestore(), 'users/owner');
  await savePhoto();
  await updateDoc(profile, { avatarStoragePath: firestoreAvatar, avatarCleanupPaths: [] });
  await assertFails(deleteDoc(doc(owner.firestore(), firestoreAvatar)));
  await savePhoto(owner, firestoreReplacement);
  await updateDoc(profile, { avatarStoragePath: firestoreReplacement, avatarCleanupPaths: [firestoreAvatar] });
  await assertSucceeds(deleteDoc(doc(owner.firestore(), firestoreAvatar)));
  await assertFails(deleteDoc(doc(owner.firestore(), firestoreReplacement)));
  await updateDoc(profile, { avatarStoragePath: deleteField(), avatarCleanupPaths: [firestoreReplacement] });
  await assertSucceeds(deleteDoc(doc(owner.firestore(), firestoreReplacement)));
  const data = (await getDoc(profile)).data();
  assert.equal(data.avatarStoragePath, undefined);
  assert.equal(data.displayName, 'Jamie');
  assert.equal(data.email, 'private@example.com');
  assert.equal(data.preferredCurrencyCode, 'USD');
  assert.equal(data.notificationsEnabled, true);
  assert.equal((await getDoc(doc(owner.firestore(), 'users/owner/goals/keep'))).data().savedAmount, 1000);
  assert.equal((await getDoc(doc(owner.firestore(), 'users/owner/tasks/keep'))).data().title, 'Keep me');
});
test('Spark orphan query excludes the active avatar without a composite index', async () => {
  await savePhoto();
  await savePhoto(owner, firestoreReplacement);
  const result = await assertSucceeds(getDocs(query(
    collection(owner.firestore(), 'users/owner/profilePhotos'),
    where(documentId(), '!=', 'AAAAAAAAAAAAAAAAAAAA'),
  )));
  assert.deepEqual(result.docs.map((d) => d.id), ['BBBBBBBBBBBBBBBBBBBB']);
});
