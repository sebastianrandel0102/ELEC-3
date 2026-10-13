"use strict";
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {onCall} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {cleanupCoverEntry, sweepGoalCovers} = require("./goal_covers");
const {createSharedService} = require("./shared");
initializeApp();
const service = createSharedService(getFirestore());
// Authentication and per-user rate limiting are enforced in the service.
// App Check can additionally be enforced after registering all client platforms.
exports.sharedSavings = onCall({region: "us-central1", maxInstances: 10, timeoutSeconds: 60}, service);

// Optional deployed maintenance complements the client's retryable journal.
// Covers use new immutable IDs and transfers time out after 90 seconds. Waiting
// 24 hours before sweeping staged uploads excludes active application updates.
exports.sweepGoalCovers = onSchedule({schedule: "every 24 hours", region: "us-central1", timeoutSeconds: 540},
  async () => sweepGoalCovers(getFirestore(), getStorage().bucket(), new Date(Date.now() - 86400000)));
exports.cleanupDeletedGoalCovers = onDocumentDeleted({document: "users/{uid}/goals/{goalId}",
  region: "us-central1", retry: true}, async event => {
  const db = getFirestore();
  const journal = await db.collection(`users/${event.params.uid}/goalCoverUploads`)
    .where('goalId', '==', event.params.goalId).get();
  for (const entry of journal.docs) {
    if (entry.data().shared === false) await cleanupCoverEntry(db, getStorage().bucket(), entry);
  }
});
