"use strict";
const {test, after} = require("node:test");
const assert = require("node:assert/strict");
const {randomBytes, createHash} = require("node:crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {createSharedService, cents, date} = require("../shared");
const projectId = "demo-savetrack-withdrawal";
const emulator = process.env.FIRESTORE_EMULATOR_HOST;
if (!emulator || !emulator.startsWith("127.0.0.1:")) throw new Error("Run through test/run_shared_emulator.py; real Firebase access is forbidden.");
const app = initializeApp({projectId}), db = getFirestore(app);
const now = Date.UTC(2026, 9, 12, 12), service = createSharedService(db, () => now);
const rid = () => randomBytes(12).toString("hex");
const identity = (prefix = "owner") => ({uid: `${prefix}-${rid()}`, token: {name: prefix}});
const call = (auth, action, data = {}, requestId = rid()) => service({auth, data: {action, ...data, requestId}});
const fields = {name: "Holiday", targetAmount: "30000.00", initialAmount: "100.25", startDate: "2026-01-01", deadline: "2026-12-30", description: "Friends save together", iconKey: "travel"};
async function setup() { const owner = identity(); const {goalId} = await call(owner, "create", fields); return {owner, goalId}; }
async function join(owner, goalId, user = identity("member")) { const invite = await call(owner, "invite", {goalId}); await call(user, "accept", {token: invite.token}); return user; }
const goal = async id => (await db.doc(`sharedGoals/${id}`).get()).data();
const reject = (promise, code) => assert.rejects(promise, e => e.code === code);
const money = (amount, goalId) => ({goalId, amount, note: "Recorded savings", date: "2026-10-12"});
function jwt(uid) {
  const encode = value => Buffer.from(JSON.stringify(value)).toString("base64url");
  return `${encode({alg: "none", typ: "JWT"})}.${encode({sub: uid, user_id: uid, aud: projectId, iss: `https://securetoken.google.com/${projectId}`, iat: Math.floor(Date.now()/1000), exp: Math.floor(Date.now()/1000)+3600, firebase: {sign_in_provider: "anonymous"}})}.`;
}
async function rest(path, uid, method = "GET", body) {
  const response = await fetch(`http://${emulator}/v1/projects/${projectId}/databases/(default)/documents${path.startsWith(':') ? '' : '/'}${path}`, {method, headers: {"Content-Type": "application/json", ...(uid ? {Authorization: `Bearer ${jwt(uid)}`} : {})}, ...(body ? {body: JSON.stringify(body)} : {})});
  return {status: response.status, body: await response.json()};
}
after(async () => {await db.terminate(); await deleteApp(app);});

test("currency and dates reject invalid precision, signs, infinity and impossible dates", () => {
  assert.equal(cents("0.29"), 29); assert.equal(cents("10.01"), 1001);
  for (const v of ["-1", "1e3", "1.001", "NaN", "Infinity", "1000000000.01", 10, "0"]) assert.throws(() => cents(v));
  assert.equal(cents("0", true), 0); assert.throws(() => date("2026-02-30"));
});
test("creation is atomic, assigns owner and records initial ledger", async () => {
  const {owner, goalId} = await setup(), g = await goal(goalId);
  assert.equal(g.ownerId, owner.uid); assert.deepEqual(g.memberIds, [owner.uid]); assert.equal(g.currentAmount, 100.25);
  assert.equal(g.personalDeposits[owner.uid], 100.25);
  assert.equal((await db.doc(`sharedGoals/${goalId}/members/${owner.uid}`).get()).data().role, "owner");
  assert.equal((await db.collection(`sharedGoals/${goalId}/transactions`).get()).size, 1);
});
test("duplicate creation retries return one goal, changed retry rejected", async () => {
  const owner = identity(), requestId = rid();
  const [a, b] = await Promise.all([call(owner, "create", fields, requestId), call(owner, "create", fields, requestId)]);
  assert.equal(a.goalId, b.goalId); assert.equal((await db.collection("sharedGoals").where("ownerId", "==", owner.uid).get()).size, 1);
  await reject(call(owner, "create", {...fields, name: "Different"}, requestId), "already-exists");
});
test("unauthenticated operations and impersonation are rejected", async () => {
  await reject(call(null, "create", fields), "unauthenticated");
  const {owner, goalId} = await setup();
  await reject(call(owner, "contribute", {...money("50", goalId), contributorId: "victim"}), "invalid-argument");
});
test("only active members can read; goal discovery queries respect membership", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId);
  assert.equal((await rest(`sharedGoals/${goalId}`, owner.uid)).status, 200);
  assert.equal((await rest(`sharedGoals/${goalId}`, member.uid)).status, 200);
  assert.equal((await rest(`sharedGoals/${goalId}`, identity("stranger").uid)).status, 403);
  assert.equal((await rest(`sharedGoals/${goalId}`)).status, 403);
  const query = {structuredQuery: {from: [{collectionId: "sharedGoals"}], where: {fieldFilter: {field: {fieldPath: "memberIds"}, op: "ARRAY_CONTAINS", value: {stringValue: member.uid}}}}};
  assert.equal((await rest(":runQuery", member.uid, "POST", query)).status, 200);
  assert.equal((await rest(":runQuery", member.uid, "POST", {structuredQuery: {from: [{collectionId: "sharedGoals"}]}})).status, 403);
});
test("direct client edits, memberships and transactions are denied", async () => {
  const {owner, goalId} = await setup();
  for (const path of [`sharedGoals/${goalId}`, `sharedGoals/${goalId}/members/${owner.uid}`, `sharedGoals/${goalId}/transactions/forged`]) {
    assert.equal((await rest(path, owner.uid, "PATCH", {fields: {amount: {doubleValue: 999}}})).status, 403);
  }
});
test("invitation token is random, hash protected and metadata owner-only", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId);
  const result = await call(owner, "invite", {goalId});
  assert.match(result.token, /^[A-Za-z0-9_-]{43}$/);
  const hash = createHash("sha256").update(result.token).digest("hex");
  const secret = (await db.doc(`sharedInvitationSecrets/${hash}`).get()).data(); assert.equal(secret.goalId, goalId);
  assert.equal((await rest(`sharedInvitationSecrets/${hash}`, owner.uid)).status, 403);
  assert.equal((await rest(`sharedGoals/${goalId}/invitations/${result.invitationId}`, member.uid)).status, 403);
  assert.equal((await rest(`sharedGoals/${goalId}/invitations/${result.invitationId}`, owner.uid)).status, 200);
  await reject(call(member, "invite", {goalId}), "permission-denied");
});
test("invalid, expired, revoked and declined invitations do not add members", async () => {
  const {owner, goalId} = await setup(), user = identity("recipient");
  await reject(call(user, "preview", {token: rid()}), "not-found");
  const expired = await call(owner, "invite", {goalId});
  await db.doc(`sharedGoals/${goalId}/invitations/${expired.invitationId}`).update({expiresAt: Timestamp.fromMillis(now - 1)});
  assert.match((await call(user, "accept", {token: expired.token})).error, /expired/);
  const revoked = await call(owner, "invite", {goalId}); await call(owner, "revoke", {goalId, invitationId: revoked.invitationId});
  await reject(call(user, "accept", {token: revoked.token}), "failed-precondition");
  const declined = await call(owner, "invite", {goalId}); await call(user, "decline", {token: declined.token});
  await reject(call(user, "accept", {token: declined.token}), "failed-precondition");
  assert.equal((await goal(goalId)).memberCount, 1);
});
test("preview discloses only invitation information and does not grant reads", async () => {
  const {owner, goalId} = await setup(), user = identity("recipient"), invitation = await call(owner, "invite", {goalId});
  const preview = await call(user, "preview", {token: invitation.token});
  assert.equal(preview.name, "Holiday"); assert.equal(preview.currentAmount, undefined);
  assert.equal((await rest(`sharedGoals/${goalId}`, user.uid)).status, 403);
});
test("acceptance retries and repeated acceptance never duplicate membership", async () => {
  const {owner, goalId} = await setup(), user = identity("recipient"), invite = await call(owner, "invite", {goalId}), requestId = rid();
  await Promise.all([call(user, "accept", {token: invite.token}, requestId), call(user, "accept", {token: invite.token}, requestId)]);
  await call(user, "accept", {token: invite.token});
  assert.equal((await goal(goalId)).memberCount, 2);
  await reject(call(identity("other"), "accept", {token: invite.token}), "failed-precondition");
});
test("contribution updates balance, member summary and immutable attributed ledger", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId), requestId = rid();
  await call(member, "contribute", money("0.29", goalId), requestId);
  const g = await goal(goalId); assert.equal(g.currentAmount, 100.54); assert.equal(g.totalDeposits, 100.54); assert.equal(g.personalDeposits[member.uid], 0.29);
  const record = (await db.doc(`sharedGoals/${goalId}/transactions/${requestId}`).get()).data();
  assert.equal(record.contributorId, member.uid); assert.equal(record.amount, 0.29);
  assert.equal((await rest(`sharedGoals/${goalId}/transactions/${requestId}`, member.uid, "PATCH", {fields: {amount: {doubleValue: 5}}})).status, 403);
});
test("concurrent contributions and duplicate submissions conserve the ledger", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId), duplicate = rid();
  await Promise.all([call(owner, "contribute", money("10.01", goalId)), call(member, "contribute", money("20.02", goalId)), call(member, "contribute", money("5", goalId), duplicate), call(member, "contribute", money("5", goalId), duplicate)]);
  const records = await db.collection(`sharedGoals/${goalId}/transactions`).get();
  assert.equal(records.size, 4); assert.equal((await goal(goalId)).currentAmount, 135.28);
  assert.equal(records.docs.reduce((total, d) => total + Math.round(d.data().amount * 100), 0), 13528);
});
test("nonmembers, invalid amounts, out of range dates cannot contribute", async () => {
  const {owner, goalId} = await setup();
  await reject(call(identity("stranger"), "contribute", money("100", goalId)), "permission-denied");
  for (const amount of ["0", "-1", "1.001"]) await reject(call(owner, "contribute", money(amount, goalId)), "invalid-argument");
  await reject(call(owner, "contribute", {...money("1", goalId), date: "2027-01-01"}), "invalid-argument");
});
test("owner-only decreases preserve deposit attribution and reject negative balances", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId);
  await call(member, "contribute", money("20", goalId));
  await reject(call(member, "decrease", money("1", goalId)), "permission-denied");
  await reject(call(owner, "decrease", money("121", goalId)), "failed-precondition");
  const requestId = rid(); await call(owner, "decrease", money("30", goalId), requestId); await call(owner, "decrease", money("30", goalId), requestId);
  const g = await goal(goalId); assert.equal(g.currentAmount, 90.25); assert.equal(g.totalDeposits, 120.25); assert.equal(g.totalDecreases, 30); assert.equal(g.personalDeposits[member.uid], 20);
});
test("removal revokes all reads and writes while preserving deposits", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId);
  const deposited = rid();
  await call(member, "contribute", money("20", goalId), deposited);
  await reject(call(member, "remove", {goalId, memberId: owner.uid}), "permission-denied");
  await call(owner, "remove", {goalId, memberId: member.uid});
  assert.equal((await goal(goalId)).currentAmount, 120.25);
  assert.equal((await db.doc(`sharedGoals/${goalId}/members/${member.uid}`).get()).data().totalDeposits, 20);
  for (const path of [`sharedGoals/${goalId}`, `sharedGoals/${goalId}/members/${owner.uid}`]) assert.equal((await rest(path, member.uid)).status, 403);
  await reject(call(member, "contribute", money("1", goalId)), "permission-denied");
  await reject(call(member, "contribute", money("20", goalId), deposited), "permission-denied");
  const invitation = await call(owner, "invite", {goalId}); await reject(call(member, "accept", {token: invitation.token}), "permission-denied");
});
test("all failed invitation attempts count against the per-user rate limit", async () => {
  const user = identity("rate-test");
  for (let i = 0; i < 90; i++) await reject(call(user, "preview", {token: rid()}), "not-found");
  await reject(call(user, "preview", {token: rid()}), "resource-exhausted");
});
test("leaving preserves history and owner cannot leave", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId);
  await call(member, "contribute", money("20", goalId)); await call(member, "leave", {goalId});
  assert.equal((await goal(goalId)).currentAmount, 120.25); assert.equal((await goal(goalId)).memberCount, 1);
  await reject(call(owner, "leave", {goalId}), "failed-precondition");
});
test("editing and archiving are owner-only; archive blocks contributions and invites", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId);
  await reject(call(member, "edit", {...fields, goalId}), "permission-denied");
  await call(owner, "edit", {...fields, goalId, name: "Updated", targetAmount: "50"}); assert.equal((await goal(goalId)).status, "completed");
  await call(owner, "decrease", money("60", goalId)); assert.equal((await goal(goalId)).status, "active");
  await call(owner, "archive", {goalId});
  await reject(call(member, "contribute", money("1", goalId)), "failed-precondition");
  await reject(call(owner, "invite", {goalId}), "failed-precondition");
  assert.equal((await rest(`sharedGoals/${goalId}`, member.uid)).status, 200);
});

test("Manila dates at midnight are accepted and future initial savings are rejected", async () => {
  const localService = createSharedService(db, () => Date.parse("2026-10-11T16:30:00Z"));
  const {owner, goalId} = await setup();
  const request = (action, data) => localService({auth: owner, data: {action, ...data, requestId: rid()}});
  await request("contribute", money("1", goalId));
  await reject(request("contribute", {...money("1", goalId), date: "2026-10-13"}), "invalid-argument");
  await reject(request("create", {...fields, startDate: "2026-11-01"}), "invalid-argument");
});
test("concurrent decreases use the latest balance and cannot overdraw", async () => {
  const {owner, goalId} = await setup();
  const result = await Promise.allSettled([call(owner, "decrease", money("75", goalId)), call(owner, "decrease", money("75", goalId))]);
  assert.equal(result.filter(r => r.status === "fulfilled").length, 1);
  assert.equal((await goal(goalId)).currentAmount, 25.25);
});
test("retrying invitation creation does not duplicate or persist the raw code", async () => {
  const {owner, goalId} = await setup(), requestId = rid();
  const original = await call(owner, "invite", {goalId}, requestId);
  const retry = await call(owner, "invite", {goalId}, requestId);
  assert.equal(retry.invitationId, original.invitationId);
  assert.equal(retry.token, null);
  const receipt = (await db.doc(`sharedOperations/${owner.uid}/requests/${requestId}`).get()).data();
  assert.equal(JSON.stringify(receipt).includes(original.token), false);
  assert.equal((await db.collection(`sharedGoals/${goalId}/invitations`).get()).size, 1);
});
test("member limit, pending invitation limit and authenticated rate limits are enforced", async () => {
  const {owner, goalId} = await setup(), user = identity("member");
  const invitation = await call(owner, "invite", {goalId});
  await db.doc(`sharedGoals/${goalId}`).update({memberCount: 50});
  await reject(call(user, "accept", {token: invitation.token}), "resource-exhausted");
  const batch = db.batch();
  for (let i = 0; i < 19; i++) batch.set(db.doc(`sharedGoals/${goalId}/invitations/${rid()}`), {status: "pending", expiresAt: Timestamp.fromMillis(now + 10000)});
  await batch.commit();
  await reject(call(owner, "invite", {goalId}), "resource-exhausted");
  await db.doc(`sharedRateLimits/${owner.uid}`).set({minute: Math.floor(now / 60000), count: 90});
  await reject(call(owner, "preview", {token: invitation.token}), "resource-exhausted");
});
test("leaving and rejoining retain deposit totals while removal blocks redemption", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId);
  await call(member, "contribute", money("20", goalId));
  await call(member, "leave", {goalId});
  await join(owner, goalId, member);
  const g = await goal(goalId);
  assert.equal(g.currentAmount, 120.25); assert.equal(g.personalDeposits[member.uid], 20);
  assert.equal(g.memberCount, 2);
  assert.equal((await db.doc(`sharedGoals/${goalId}/members/${member.uid}`).get()).data().totalDeposits, 20);
});
test("removed member cannot read the ledger, invitation metadata, or create access references", async () => {
  const {owner, goalId} = await setup(), member = await join(owner, goalId);
  const records = await db.collection(`sharedGoals/${goalId}/transactions`).get();
  const transactionId = records.docs[0].id;
  await call(owner, "remove", {goalId, memberId: member.uid});
  assert.equal((await rest(`sharedGoals/${goalId}/transactions/${transactionId}`, member.uid)).status, 403);
  assert.equal((await rest(`users/${member.uid}/sharedGoalRefs/${goalId}`, member.uid, "PATCH", {fields: {goalId: {stringValue: goalId}}})).status, 403);
  assert.equal((await rest(`sharedOperations/${owner.uid}/requests/${rid()}`, member.uid)).status, 403);
});
