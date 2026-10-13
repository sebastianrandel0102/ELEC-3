"use strict";

// Journal validation is repeated on the trusted cleanup boundary. Never delete
// profile photos or objects outside the exact immutable cover namespace.
function coverEntry(entry) {
  const parts = entry.ref.path.split('/');
  const data = entry.data();
  if (parts.length !== 4 || parts[0] !== 'users' || parts[2] !== 'goalCoverUploads' ||
      !/^[A-Za-z0-9]{20}$/.test(parts[3]) || typeof data.goalId !== 'string' ||
      !data.goalId || data.goalId.includes('/') || typeof data.shared !== 'boolean') return null;
  const uid = parts[1];
  const goalPath = data.shared ? `sharedGoals/${data.goalId}` : `users/${uid}/goals/${data.goalId}`;
  const storagePath = `${goalPath}/cover/${parts[3]}.jpg`;
  const photoPath = `${goalPath}/coverPhotos/${parts[3]}`;
  if (data.storagePath !== storagePath && data.storagePath !== photoPath) return null;
  return {uid, goalPath, storagePath: data.storagePath, shared: data.shared,
    firestore: data.storagePath === photoPath};
}

async function cleanupCoverEntry(db, bucket, entry) {
  const target = coverEntry(entry);
  if (!target) return false;
  if (target.firestore) {
    // Admin bypasses client rules: the root read and deletions must be atomic
    // so a concurrent cover commit cannot make this photo current mid-cleanup.
    return db.runTransaction(async tx => {
      const goal = await tx.get(db.doc(target.goalPath));
      if (goal.exists && (goal.data().coverStoragePath === target.storagePath ||
          (target.shared && goal.data().ownerId !== target.uid))) return false;
      tx.delete(db.doc(target.storagePath));
      tx.delete(entry.ref);
      return true;
    });
  }
  const goal = await db.doc(target.goalPath).get();
  if (goal.exists) {
    const record = goal.data();
    if (record.coverStoragePath === target.storagePath || (target.shared && record.ownerId !== target.uid)) return false;
  }
  const file = bucket.file(target.storagePath);
  try {
    const [metadata] = await file.getMetadata();
    await file.delete({ifGenerationMatch: metadata.generation});
  } catch (error) {
    if (Number(error.code) !== 404) throw error;
  }
  await entry.ref.delete();
  return true;
}

async function sweepGoalCovers(db, bucket, cutoff) {
  let cursor;
  // Page past retained active covers; they must not starve later orphan entries.
  for (;;) {
    let query = db.collectionGroup('goalCoverUploads').where('createdAt', '<', cutoff).orderBy('createdAt').limit(250);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const entry of page.docs) await cleanupCoverEntry(db, bucket, entry);
    cursor = page.docs.at(-1);
    if (page.size < 250) break;
  }
}

module.exports = {coverEntry, cleanupCoverEntry, sweepGoalCovers};
