"use strict";
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {onCall} = require("firebase-functions/v2/https");
const {createSharedService} = require("./shared");
initializeApp();
const service = createSharedService(getFirestore());
// Authentication and per-user rate limiting are enforced in the service.
// App Check can additionally be enforced after registering all client platforms.
exports.sharedSavings = onCall({region: "us-central1", maxInstances: 10, timeoutSeconds: 60}, service);
