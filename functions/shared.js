"use strict";
const {randomBytes, createHash} = require("node:crypto");
const {Timestamp, FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const MAX_CENTS = 100000000000; // PHP 1 billion; exact integer arithmetic.
const MAX_MEMBERS = 50;
const fail = (code, message) => { throw new HttpsError(code, message); };
const hash = value => createHash("sha256").update(value).digest("hex");
function text(value, name, max = 500, required = false) {
  if (typeof value !== "string" || value.trim().length > max || (required && !value.trim())) {
    fail("invalid-argument", `Invalid ${name}.`);
  }
  return value.trim();
}
function id(value, name) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{16,128}$/.test(value)) fail("invalid-argument", `Invalid ${name}.`);
  return value;
}
function cents(value, allowZero = false) {
  if (typeof value !== "string" || !/^\d+(?:\.\d{1,2})?$/.test(value)) fail("invalid-argument", "Use a positive PHP amount with at most two decimal places.");
  const [whole, fraction = ""] = value.split(".");
  const result = Number(whole) * 100 + Number(fraction.padEnd(2, "0"));
  if (!Number.isSafeInteger(result) || result > MAX_CENTS || result < (allowZero ? 0 : 1)) fail("invalid-argument", "Amount is outside the supported range.");
  return result;
}
function date(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) fail("invalid-argument", "Invalid date.");
  const parsed = new Date(`${value}T00:00:00Z`);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value || value < "2000-01-01" || value > "2100-12-31") fail("invalid-argument", "Invalid date.");
  return Timestamp.fromDate(parsed);
}
function goalFields(data) {
  const startDate = date(data.startDate), deadline = date(data.deadline);
  if (startDate.toMillis() > deadline.toMillis()) fail("invalid-argument", "Start date must be on or before the deadline.");
  const iconKey = text(data.iconKey, "icon", 20, true);
  if (!["group", "travel", "home", "school", "gift", "emergency"].includes(iconKey)) fail("invalid-argument", "Invalid goal icon.");
  return {name: text(data.name, "goal name", 100, true), description: text(data.description ?? "", "description", 1000), targetAmount: cents(data.targetAmount) / 100, startDate, deadline, iconKey};
}
function memberName(auth) {
  // Never fall back to an email, and never query unrelated private profiles.
  return typeof auth.token?.name === "string" ? auth.token.name.slice(0, 100) : "SaveTrack member";
}
function activeMember(goal, member, uid) {
  if (!goal || !member || member.status !== "active" || !goal.memberIds.includes(uid)) fail("permission-denied", "You no longer have access to this shared goal.");
}
function owner(goal, member, uid) {
  activeMember(goal, member, uid);
  if (goal.ownerId !== uid || member.role !== "owner") fail("permission-denied", "Only the owner can perform this action.");
}
function open(goal) {
  if (goal.status === "archived") fail("failed-precondition", "This goal is archived.");
}
function totalCents(value) {
  const result = Math.round(value * 100);
  if (!Number.isSafeInteger(result) || result < 0 || result > MAX_CENTS) fail("failed-precondition", "The stored balance requires review.");
  return result;
}
function status(goal, currentAmount = goal.currentAmount, targetAmount = goal.targetAmount) {
  return goal.status === "archived" ? "archived" : currentAmount >= targetAmount ? "completed" : "active";
}
function todayManila(milliseconds) {
  return new Intl.DateTimeFormat("en-CA", {timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit"}).format(milliseconds);
}
function createSharedService(db, now = () => Date.now()) {
  async function throttle(uid) {
    const ref = db.doc(`sharedRateLimits/${uid}`);
    await db.runTransaction(async tx => {
      const previous = (await tx.get(ref)).data();
      const minute = Math.floor(now() / 60000);
      const count = previous?.minute === minute ? previous.count + 1 : 1;
      if (count > 90) fail("resource-exhausted", "Too many requests. Please wait a minute.");
      tx.set(ref, {minute, count, expiresAt: Timestamp.fromMillis(now() + 86400000)});
    });
  }
  return async request => {
    if (!request.auth?.uid) fail("unauthenticated", "Sign in to use Save Together.");
    const uid = request.auth.uid, data = request.data;
    if (!data || typeof data !== "object" || Array.isArray(data)) fail("invalid-argument", "Invalid request.");
    await throttle(uid);
    const action = data.action;
    const actions = ["create", "edit", "contribute", "decrease", "invite", "preview", "accept", "decline", "revoke", "remove", "leave", "archive"];
    if (!actions.includes(action)) fail("invalid-argument", "Unknown shared goal operation.");
    // Actor identity is always the authenticated UID; client impersonation is rejected.
    if (data.contributorId !== undefined || data.ownerId !== undefined || data.userId !== undefined) fail("invalid-argument", "Do not supply an actor identity.");
    const operationId = action === "preview" ? null : id(data.requestId, "request ID");
    const operationRef = operationId ? db.doc(`sharedOperations/${uid}/requests/${operationId}`) : null;
    const fingerprint = hash(JSON.stringify(Object.fromEntries(Object.entries(data).sort(([a], [b]) => a.localeCompare(b)))));
    const generatedGoalId = db.collection("sharedGoals").doc().id;
    const generatedInviteId = db.collection("sharedGoals").doc().id;
    const generatedToken = randomBytes(32).toString("base64url");
    const tokenHash = ["preview", "accept", "decline"].includes(action) ? hash(id(data.token, "invitation code")) : null;
    return db.runTransaction(async tx => {
      const operation = operationRef ? (await tx.get(operationRef)).data() : null;
      if (operation) {
        if (operation.fingerprint !== fingerprint) fail("already-exists", "This request ID was already used with different values. Reopen the form.");
        // A receipt is proof of a past write, never a substitute for current access.
        const receiptGoal = action === "accept" ? operation.result.goalId : data.goalId;
        if (receiptGoal && action !== "leave" && action !== "decline") {
          const previousGoal = (await tx.get(db.doc(`sharedGoals/${id(receiptGoal, "goal ID")}`))).data();
          const previousMember = (await tx.get(db.doc(`sharedGoals/${receiptGoal}/members/${uid}`))).data();
          activeMember(previousGoal, previousMember, uid);
          if (!["contribute", "accept"].includes(action)) owner(previousGoal, previousMember, uid);
        }
        return operation.result; // No raw invite code is stored in the receipt.
      }
      const stamp = FieldValue.serverTimestamp();
      const complete = result => {
        if (operationRef) tx.create(operationRef, {fingerprint, result, createdAt: stamp});
        return result;
      };
      if (action === "create") {
        const fields = goalFields(data), initialCents = cents(data.initialAmount ?? "0", true);
        if (initialCents && data.startDate > todayManila(now())) fail("invalid-argument", "Initial savings cannot be dated in the future.");
        const goalId = generatedGoalId, goalRef = db.doc(`sharedGoals/${goalId}`);
        const goal = {...fields, ownerId: uid, ownerName: memberName(request.auth), memberIds: [uid], memberNames: {[uid]: memberName(request.auth)}, personalDeposits: {[uid]: initialCents / 100}, memberCount: 1, currentAmount: initialCents / 100, totalDeposits: initialCents / 100, totalDecreases: 0, createdAt: stamp, updatedAt: stamp, status: initialCents >= totalCents(fields.targetAmount) ? "completed" : "active"};
        tx.create(goalRef, goal);
        tx.create(goalRef.collection("members").doc(uid), {userId: uid, displayName: memberName(request.auth), role: "owner", status: "active", totalDeposits: initialCents / 100, joinedAt: stamp});
        if (initialCents) tx.create(goalRef.collection("transactions").doc(operationId), {goalId, contributorId: uid, displayName: memberName(request.auth), type: "deposit", amount: initialCents / 100, date: fields.startDate, note: "Initial savings", createdAt: stamp});
        return complete({goalId});
      }
      let secretRef, secret, inviteRef, invitation;
      if (tokenHash) {
        secretRef = db.doc(`sharedInvitationSecrets/${tokenHash}`);
        secret = (await tx.get(secretRef)).data();
        if (!secret) fail("not-found", "Invalid invitation code.");
        inviteRef = db.doc(`sharedGoals/${secret.goalId}/invitations/${secret.invitationId}`);
        invitation = (await tx.get(inviteRef)).data();
        if (!invitation || invitation.status !== "pending") {
          if (action === "accept" && invitation?.status === "accepted" && invitation.recipientId === uid) {
            const joined = (await tx.get(db.doc(`sharedGoals/${secret.goalId}/members/${uid}`))).data();
            if (joined?.status === "active") return complete({goalId: secret.goalId, alreadyJoined: true});
          }
          fail("failed-precondition", `Invitation is ${invitation?.status ?? "unavailable"}.`);
        }
        if (invitation.expiresAt.toMillis() <= now()) {
          tx.update(inviteRef, {status: "expired", updatedAt: stamp});
          return {error: "Invitation has expired."};
        }
      }
      const goalId = tokenHash ? secret.goalId : id(data.goalId, "goal ID");
      const goalRef = db.doc(`sharedGoals/${goalId}`), memberRef = goalRef.collection("members").doc(uid);
      const goal = (await tx.get(goalRef)).data(), member = (await tx.get(memberRef)).data();
      if (!goal) fail("not-found", "This shared goal no longer exists.");
      if (tokenHash) {
        open(goal);
        if (action === "preview") return {goalId, name: goal.name, ownerName: goal.ownerName, targetAmount: goal.targetAmount, expiresAt: invitation.expiresAt.toMillis()};
        if (action === "decline") {
          // Codes are single-recipient bearer capabilities: declining consumes the code.
          tx.update(inviteRef, {status: "declined", recipientId: uid, updatedAt: stamp});
          return complete({declined: true});
        }
        if (member?.status !== "active" && goal.memberCount >= MAX_MEMBERS) fail("resource-exhausted", "This goal has reached its 50-member limit.");
        if (member?.status === "removed") fail("permission-denied", "Your membership was removed. Contact the owner.");
        if (member?.status !== "active") {
          tx.set(memberRef, {userId: uid, displayName: memberName(request.auth), role: "contributor", status: "active", totalDeposits: member?.totalDeposits ?? 0, joinedAt: stamp});
          tx.update(goalRef, {memberIds: [...goal.memberIds, uid], memberNames: {...goal.memberNames, [uid]: memberName(request.auth)}, personalDeposits: {...goal.personalDeposits, [uid]: member?.totalDeposits ?? 0}, memberCount: goal.memberCount + 1, updatedAt: stamp});
        }
        tx.update(inviteRef, {status: "accepted", recipientId: uid, updatedAt: stamp});
        return complete({goalId});
      }
      activeMember(goal, member, uid);
      if (!["contribute", "leave"].includes(action)) owner(goal, member, uid);
      if (["contribute", "decrease"].includes(action)) {
        open(goal);
        const amount = cents(data.amount), current = totalCents(goal.currentAmount);
        const balance = current + (action === "contribute" ? amount : -amount);
        if (balance < 0) fail("failed-precondition", "You cannot decrease more than the current shared balance.");
        if (balance > MAX_CENTS) fail("failed-precondition", "The shared balance exceeds the supported range.");
        const contributionDate = date(data.date);
        if (contributionDate.toMillis() < goal.startDate.toMillis() || data.date > todayManila(now())) fail("invalid-argument", "Choose a contribution date between the start date and today.");
        const depositTotal = totalCents(goal.totalDeposits) + (action === "contribute" ? amount : 0);
        const decreaseTotal = totalCents(goal.totalDecreases) + (action === "decrease" ? amount : 0);
        if (depositTotal > MAX_CENTS || decreaseTotal > MAX_CENTS) fail("failed-precondition", "Recorded totals exceed the supported range.");
        tx.create(goalRef.collection("transactions").doc(operationId), {goalId, contributorId: uid, displayName: member.displayName, type: action === "contribute" ? "deposit" : "withdrawal", amount: amount / 100, date: contributionDate, note: text(data.note ?? "", "note", 500), createdAt: stamp});
        tx.update(goalRef, {currentAmount: balance / 100, totalDeposits: depositTotal / 100, totalDecreases: decreaseTotal / 100, ...(action === "contribute" ? {personalDeposits: {...goal.personalDeposits, [uid]: (totalCents(member.totalDeposits) + amount) / 100}} : {}), status: status(goal, balance / 100), updatedAt: stamp});
        if (action === "contribute") tx.update(memberRef, {totalDeposits: (totalCents(member.totalDeposits) + amount) / 100});
        return complete({goalId, currentAmount: balance / 100});
      }
      if (action === "edit") {
        open(goal);
        const fields = goalFields(data);
        // Start date defines ledger eligibility and cannot be moved by ordinary editing.
        if (fields.startDate.toMillis() !== goal.startDate.toMillis()) fail("invalid-argument", "The start date cannot change after creation.");
        tx.update(goalRef, {...fields, status: status(goal, goal.currentAmount, fields.targetAmount), updatedAt: stamp});
        return complete({goalId});
      }
      if (action === "invite") {
        open(goal);
        const pending = await tx.get(goalRef.collection("invitations")
          .where("status", "==", "pending").where("expiresAt", ">", Timestamp.fromMillis(now())).limit(20));
        if (pending.size >= 20) fail("resource-exhausted", "Revoke an invitation before creating more.");
        const invitationId = generatedInviteId, expiresAt = Timestamp.fromMillis(now() + 7 * 86400000);
        tx.create(goalRef.collection("invitations").doc(invitationId), {createdBy: uid, status: "pending", expiresAt, createdAt: stamp, updatedAt: stamp});
        tx.create(db.doc(`sharedInvitationSecrets/${hash(generatedToken)}`), {goalId, invitationId, expiresAt});
        complete({goalId, invitationId, expiresAt: expiresAt.toMillis(), token: null});
        return {goalId, invitationId, expiresAt: expiresAt.toMillis(), token: generatedToken};
      }
      if (action === "revoke") {
        const ref = goalRef.collection("invitations").doc(id(data.invitationId, "invitation ID"));
        const invite = (await tx.get(ref)).data();
        if (!invite) fail("not-found", "Invitation no longer exists.");
        if (invite.status !== "pending") fail("failed-precondition", "Only pending invitations can be revoked.");
        tx.update(ref, {status: "revoked", updatedAt: stamp});
        return complete({revoked: true});
      }
      if (["remove", "leave"].includes(action)) {
        const targetUid = action === "leave" ? uid : text(data.memberId, "member", 128, true);
        if (targetUid.includes("/")) fail("invalid-argument", "Invalid member.");
        if (targetUid === goal.ownerId) fail("failed-precondition", "The owner cannot leave or be removed. Archive the goal instead.");
        const targetRef = goalRef.collection("members").doc(targetUid), target = (await tx.get(targetRef)).data();
        if (!target || target.status !== "active") fail("not-found", "This member is no longer active.");
        tx.update(targetRef, {status: action === "leave" ? "left" : "removed", departedAt: stamp});
        const memberNames = {...goal.memberNames};
        const personalDeposits = {...goal.personalDeposits};
        delete memberNames[targetUid]; delete personalDeposits[targetUid];
        tx.update(goalRef, {memberIds: goal.memberIds.filter(value => value !== targetUid), memberNames, personalDeposits, memberCount: goal.memberCount - 1, updatedAt: stamp});
        return complete({left: true});
      }
      if (action === "archive") {
        tx.update(goalRef, {status: "archived", updatedAt: stamp});
        return complete({goalId});
      }
      fail("invalid-argument", "Unsupported operation.");
    });
  };
}
module.exports = {createSharedService, cents, date};
