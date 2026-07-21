import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc
} from "firebase/firestore";

const projectId = "tenisbuddy-app-rules-test";
let environment: RulesTestEnvironment;

function player(id: string, name: string, level: "novato" | "d" | "c" | "b" | "a", isDemo = false) {
  return {
    id,
    name,
    age: 30,
    gender: "other",
    clubIds: ["club-test"],
    city: "Madrid",
    country: "España",
    latitude: 40.4,
    longitude: -3.7,
    level,
    preferredFormats: ["singles"],
    availability: [],
    bio: "",
    languages: ["Español"],
    verified: true,
    profileComplete: true,
    rating: 3,
    responseRate: 100,
    ...(isDemo ? { isDemo: true } : {})
  };
}

function openMatch(ownerId: string, acceptedLevels: string[]) {
  const startsAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  return {
    fromPlayerId: ownerId,
    acceptedByPlayerId: null,
    clubId: "club-test",
    proposedAt: new Date().toISOString(),
    startsAt,
    reservationTime: "18:00-19:00",
    court: 1,
    status: "proposed",
    format: "singles",
    division: "c",
    acceptedLevels,
    message: "Partido informal de prueba",
    createdAt: serverTimestamp()
  };
}

function joinRequest(matchId: string, ownerId: string, requesterId: string, requesterName: string, requesterLevel: string) {
  return {
    id: `${matchId}_${requesterId}`,
    matchId,
    ownerId,
    requesterId,
    requesterName,
    requesterLevel,
    status: "pending",
    createdAt: new Date().toISOString(),
    createdAtServer: serverTimestamp()
  };
}

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync("firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080
    }
  });
});

test.after(async () => {
  await environment?.cleanup();
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test("solicitud, rechazo, reenvío y aceptación respetan identidades y niveles", async () => {
  const ownerId = "owner";
  const requesterId = "requester";
  const outsiderId = "outsider";
  const demoId = "demo";
  const matchId = "match-flow";
  const requestId = `${matchId}_${requesterId}`;
  const owner = environment.authenticatedContext(ownerId, { email_verified: true }).firestore();
  const requester = environment.authenticatedContext(requesterId, { email_verified: true }).firestore();
  const outsider = environment.authenticatedContext(outsiderId, { email_verified: true }).firestore();
  const demo = environment.authenticatedContext(demoId, { email_verified: true }).firestore();

  await assertSucceeds(setDoc(doc(owner, "players", ownerId), player(ownerId, "Organizador", "c")));
  await assertSucceeds(setDoc(doc(requester, "players", requesterId), player(requesterId, "Solicitante", "c")));
  await assertSucceeds(setDoc(doc(outsider, "players", outsiderId), player(outsiderId, "Fuera de nivel", "a")));
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "players", demoId), player(demoId, "Muestra", "c", true));
  });

  await assertFails(setDoc(doc(owner, "matches", "bad-levels"), openMatch(ownerId, ["c", "inventado"])));
  await assertSucceeds(setDoc(doc(owner, "matches", matchId), openMatch(ownerId, ["d", "c"])));

  await assertFails(updateDoc(doc(requester, "matches", matchId), {
    acceptedByPlayerId: requesterId,
    status: "accepted",
    updatedAt: serverTimestamp()
  }));
  await assertFails(setDoc(
    doc(requester, "matchJoinRequests", requestId),
    joinRequest(matchId, ownerId, requesterId, "Nombre manipulado", "c")
  ));
  await assertFails(setDoc(
    doc(outsider, "matchJoinRequests", `${matchId}_${outsiderId}`),
    joinRequest(matchId, ownerId, outsiderId, "Fuera de nivel", "d")
  ));
  await assertFails(setDoc(
    doc(demo, "matchJoinRequests", `${matchId}_${demoId}`),
    joinRequest(matchId, ownerId, demoId, "Muestra", "c")
  ));

  await assertSucceeds(setDoc(
    doc(requester, "matchJoinRequests", requestId),
    joinRequest(matchId, ownerId, requesterId, "Solicitante", "c")
  ));
  await assertFails(getDoc(doc(outsider, "matchJoinRequests", requestId)));
  await assertSucceeds(getDoc(doc(owner, "matchJoinRequests", requestId)));

  await assertSucceeds(updateDoc(doc(owner, "matchJoinRequests", requestId), {
    status: "declined",
    updatedAt: serverTimestamp()
  }));
  await assertSucceeds(updateDoc(doc(requester, "matchJoinRequests", requestId), {
    status: "pending",
    createdAt: new Date().toISOString(),
    createdAtServer: serverTimestamp(),
    updatedAt: serverTimestamp()
  }));

  await assertSucceeds(runTransaction(owner, async (transaction) => {
    const matchRef = doc(owner, "matches", matchId);
    const requestRef = doc(owner, "matchJoinRequests", requestId);
    const [matchSnapshot, requestSnapshot] = await Promise.all([
      transaction.get(matchRef),
      transaction.get(requestRef)
    ]);
    assert.equal(matchSnapshot.data()?.status, "proposed");
    assert.equal(requestSnapshot.data()?.status, "pending");
    transaction.update(matchRef, {
      acceptedByPlayerId: requesterId,
      status: "accepted",
      updatedAt: serverTimestamp()
    });
    transaction.update(requestRef, {
      status: "accepted",
      updatedAt: serverTimestamp()
    });
  }));

  const acceptedMatch = await getDoc(doc(owner, "matches", matchId));
  const acceptedRequest = await getDoc(doc(requester, "matchJoinRequests", requestId));
  assert.equal(acceptedMatch.data()?.acceptedByPlayerId, requesterId);
  assert.equal(acceptedMatch.data()?.status, "accepted");
  assert.equal(acceptedRequest.data()?.status, "accepted");
  await assertFails(updateDoc(doc(requester, "matchJoinRequests", requestId), { status: "pending" }));
});
