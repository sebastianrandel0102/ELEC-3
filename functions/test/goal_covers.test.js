const {test} = require('node:test');
const assert = require('node:assert/strict');
const {coverEntry, cleanupCoverEntry} = require('../goal_covers');
const version = 'AAAAAAAAAAAAAAAAAAAA';
function fixture({shared = false, exists = true, active = false, deleteError, malformed = false} = {}) {
  const storagePath = `${shared ? 'sharedGoals/goalA' : 'users/owner/goals/goalA'}/cover/${version}.jpg`;
  const events = [];
  const entry = {ref: {path: `users/owner/goalCoverUploads/${version}`, delete: async () => events.push('journal deleted')},
    data: () => ({goalId: 'goalA', shared, storagePath: malformed ? 'users/owner/profile/avatar/photo.jpg' : storagePath})};
  const db = {doc: () => ({get: async () => ({exists, data: () => ({ownerId: 'owner', coverStoragePath: active ? storagePath : undefined})})})};
  const bucket = {file: path => {events.push(path); return {
    getMetadata: async () => [{generation: '123'}],
    delete: async opts => {assert.equal(opts.ifGenerationMatch, '123'); if (deleteError) throw deleteError; events.push('image deleted');},
  };}};
  return {entry, db, bucket, events};
}
test('cleanup derives exact personal/shared paths and rejects unrelated objects', () => {
  assert.equal(coverEntry(fixture().entry).goalPath, 'users/owner/goals/goalA');
  assert.equal(coverEntry(fixture({shared: true}).entry).goalPath, 'sharedGoals/goalA');
  assert.equal(coverEntry(fixture({malformed: true}).entry), null);
});
test('backend never deletes a currently referenced personal or shared cover', async () => {
  for (const shared of [false, true]) {const f = fixture({active: true, shared});
    assert.equal(await cleanupCoverEntry(f.db, f.bucket, f.entry), false); assert.deepEqual(f.events, []);}
});
test('goal deletion and stale staged uploads clean image before journal', async () => {
  for (const exists of [false, true]) {const f = fixture({exists});
    assert.equal(await cleanupCoverEntry(f.db, f.bucket, f.entry), true);
    assert.deepEqual(f.events.slice(-2), ['image deleted', 'journal deleted']);}
});
test('temporary Storage errors retain journal for retry', async () => {
  const f = fixture({deleteError: Object.assign(new Error('offline'), {code: 503})});
  await assert.rejects(cleanupCoverEntry(f.db, f.bucket, f.entry)); assert.ok(!f.events.includes('journal deleted'));
});
test('already missing object still acknowledges journal cleanup', async () => {
  const f = fixture({deleteError: Object.assign(new Error('missing'), {code: 404})});
  await cleanupCoverEntry(f.db, f.bucket, f.entry); assert.equal(f.events.at(-1), 'journal deleted');
});

test('compact cover cleanup derives only the goal-specific Firestore document', async () => {
  const f = fixture();
  const data = {...f.entry.data(), storagePath: `users/owner/goals/goalA/coverPhotos/${version}`};
  f.entry.data = () => data;
  const target = coverEntry(f.entry);
  assert.equal(target.firestore, true);
  const deletes = [];
  const db = {doc: path => ({path}), runTransaction: async fn => fn({
    get: async ref => {assert.equal(ref.path, target.goalPath); return {exists: false};},
    delete: ref => deletes.push(ref.path),
  })};
  const unavailableBucket = {file: () => {throw new Error('Storage must not be contacted');}};
  assert.equal(await cleanupCoverEntry(db, unavailableBucket, f.entry), true);
  assert.deepEqual(deletes, [data.storagePath, f.entry.ref.path]);
});

test('compact cleanup protects the current reference and a shared goal owned by someone else', async () => {
  for (const foreignOwner of [false, true]) {
    const f = fixture({shared: true});
    const data = {...f.entry.data(), storagePath: `sharedGoals/goalA/coverPhotos/${version}`};
    f.entry.data = () => data;
    const db = {doc: path => ({path}), runTransaction: async fn => fn({
      get: async () => ({exists: true, data: () => ({ownerId: foreignOwner ? 'other' : 'owner',
        coverStoragePath: foreignOwner ? null : data.storagePath})}),
      delete: () => {throw new Error('Referenced or foreign covers must not be deleted');},
    })};
    assert.equal(await cleanupCoverEntry(db, {}, f.entry), false);
  }
});
