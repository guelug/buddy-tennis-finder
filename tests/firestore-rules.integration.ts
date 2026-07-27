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
    city: "Madrid",
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

test("la autoevaluación del onboarding se acepta solo con ejes válidos", async () => {
  const userId = "self-assessed";
  const user = environment.authenticatedContext(userId, { email_verified: true }).firestore();
  const skills = { consistency: 7, forehand: 8, backhand: 6, serve: 7, volley: 5 };

  // Crear el perfil con autoevaluación válida (el onboarding siempre la envía).
  await assertSucceeds(setDoc(doc(user, "players", userId), { ...player(userId, "Autoevaluado", "c"), skills }));

  // Valores fuera de rango o ejes desconocidos se rechazan.
  await assertFails(setDoc(doc(user, "players", userId), {
    ...player(userId, "Tramposo", "c"),
    skills: { ...skills, serve: 99 }
  }));
  await assertFails(setDoc(doc(user, "players", userId), {
    ...player(userId, "Tramposo", "c"),
    skills: { ...skills, smash: 8 }
  }));

  // Editar la autoevaluación propia más adelante también está permitido.
  await assertSucceeds(updateDoc(doc(user, "players", userId), {
    skills: { ...skills, volley: 6 },
    updatedAt: serverTimestamp()
  }));

  // Las métricas competitivas siguen siendo de solo lectura para el cliente.
  await assertFails(updateDoc(doc(user, "players", userId), { rating: 5, updatedAt: serverTimestamp() }));
});

test("un perfil antiguo puede inscribirse únicamente en ligas públicas oficiales", async () => {
  const userId = "legacy-public-league";
  const user = environment.authenticatedContext(userId, { email_verified: true }).firestore();

  await environment.withSecurityRulesDisabled(async (context) => {
    const legacy = player(userId, "Perfil antiguo", "c");
    delete (legacy as Partial<typeof legacy>).verified;
    delete (legacy as Partial<typeof legacy>).profileComplete;
    await setDoc(doc(context.firestore(), "players", userId), legacy);
  });

  await assertSucceeds(updateDoc(doc(user, "players", userId), {
    publicLeagues: ["l-c-individual"],
    updatedAt: serverTimestamp()
  }));
  await assertFails(updateDoc(doc(user, "players", userId), {
    publicLeagues: ["liga-inventada"],
    updatedAt: serverTimestamp()
  }));
});

test("las reservas admiten clubes con más de 6 canchas", async () => {
  const ownerId = "club-grande";
  const owner = environment.authenticatedContext(ownerId, { email_verified: true }).firestore();
  await assertSucceeds(setDoc(doc(owner, "players", ownerId), player(ownerId, "Organizador", "c")));

  await assertSucceeds(setDoc(doc(owner, "matches", "court-18"), { ...openMatch(ownerId, ["c"]), court: 18 }));
  await assertFails(setDoc(doc(owner, "matches", "court-25"), { ...openMatch(ownerId, ["c"]), court: 25 }));
  await assertFails(setDoc(doc(owner, "matches", "court-zero"), { ...openMatch(ownerId, ["c"]), court: 0 }));
});

test("solo el rival valida un resultado y crea una entrada de ranking inmutable", async () => {
  const ownerId = "result-owner";
  const rivalId = "result-rival";
  const matchId = "validated-result";
  const owner = environment.authenticatedContext(ownerId, { email_verified: true }).firestore();
  const rival = environment.authenticatedContext(rivalId, { email_verified: true }).firestore();

  await assertSucceeds(setDoc(doc(owner, "players", ownerId), player(ownerId, "Capitán", "c")));
  await assertSucceeds(setDoc(doc(rival, "players", rivalId), player(rivalId, "Rival", "c")));
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "matches", matchId), {
      ...openMatch(ownerId, ["c"]),
      acceptedByPlayerId: rivalId,
      status: "accepted",
      startsAt: new Date(Date.now() - 60 * 60 * 1000).toISOString()
    });
  });

  const result = {
    winner: "A",
    sets: [{ a: 6, b: 4 }, { a: 6, b: 3 }],
    reportedById: ownerId,
    reportedByName: "Capitán",
    reportedAt: new Date().toISOString()
  };
  await assertSucceeds(updateDoc(doc(owner, "matches", matchId), {
    resultStatus: "awaiting_validation",
    result,
    updatedAt: serverTimestamp()
  }));
  await assertFails(updateDoc(doc(owner, "matches", matchId), {
    resultStatus: "validated",
    validation: { playerId: ownerId, playerName: "Capitán", validatedAt: new Date().toISOString() },
    updatedAt: serverTimestamp()
  }));

  await assertSucceeds(runTransaction(rival, async (transaction) => {
    transaction.update(doc(rival, "matches", matchId), {
      resultStatus: "validated",
      validation: { playerId: rivalId, playerName: "Rival", validatedAt: new Date().toISOString() },
      updatedAt: serverTimestamp()
    });
    transaction.set(doc(rival, "rankingResults", matchId), {
      matchId,
      city: "Madrid",
      division: "c",
      playerAId: ownerId,
      playerBId: rivalId,
      winnerId: ownerId,
      playedAt: new Date().toISOString(),
      validatedById: rivalId,
      createdAt: serverTimestamp()
    });
  }));
  await assertFails(updateDoc(doc(rival, "rankingResults", matchId), { winnerId: rivalId }));
});

test("las reseñas son dirigidas, únicas y solo entre participantes de un resultado validado", async () => {
  const authorId = "review-author";
  const targetId = "review-target";
  const outsiderId = "review-outsider";
  const matchId = "reviewed-match";
  const reviewId = `${matchId}_${authorId}_${targetId}`;
  const author = environment.authenticatedContext(authorId, { email_verified: true }).firestore();
  const target = environment.authenticatedContext(targetId, { email_verified: true }).firestore();
  const outsider = environment.authenticatedContext(outsiderId, { email_verified: true }).firestore();
  const skills = { consistency: 7, forehand: 8, backhand: 6, serve: 9, volley: 5 };

  await assertSucceeds(setDoc(doc(author, "players", authorId), player(authorId, "Autor", "c")));
  await assertSucceeds(setDoc(doc(target, "players", targetId), player(targetId, "Destinatario", "c")));
  await assertSucceeds(setDoc(doc(outsider, "players", outsiderId), player(outsiderId, "Intruso", "c")));
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "matches", matchId), {
      ...openMatch(authorId, ["c"]),
      acceptedByPlayerId: targetId,
      status: "accepted",
      resultStatus: "validated"
    });
  });

  const validReview = {
    id: reviewId,
    matchId,
    authorId,
    authorName: "Autor",
    targetId,
    targetName: "Destinatario",
    stars: 5,
    skillRatings: skills,
    comment: "Gran partido.",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };

  await assertSucceeds(setDoc(doc(author, "matchReviews", reviewId), validReview));
  await assertFails(setDoc(doc(target, "matchReviews", `${matchId}_${targetId}_${targetId}`), {
    ...validReview,
    id: `${matchId}_${targetId}_${targetId}`,
    authorId: targetId,
    authorName: "Destinatario",
    targetId
  }));
  await assertFails(setDoc(doc(outsider, "matchReviews", `${matchId}_${outsiderId}_${targetId}`), {
    ...validReview,
    id: `${matchId}_${outsiderId}_${targetId}`,
    authorId: outsiderId,
    authorName: "Intruso"
  }));
  await assertFails(updateDoc(doc(target, "matchReviews", reviewId), {
    stars: 1,
    updatedAt: serverTimestamp()
  }));
  await assertSucceeds(updateDoc(doc(author, "matchReviews", reviewId), {
    stars: 4,
    skillRatings: { ...skills, serve: 8 },
    comment: "Actualizada después del partido.",
    updatedAt: serverTimestamp()
  }));
  await assertFails(updateDoc(doc(author, "matchReviews", reviewId), {
    targetId: outsiderId,
    targetName: "Intruso",
    updatedAt: serverTimestamp()
  }));
});

test("dos cuentas del mismo teléfono no pueden valorarse entre ellas", async () => {
  const authorId = "same-device-author";
  const targetId = "same-device-target";
  const matchId = "same-device-match";
  const reviewId = `${matchId}_${authorId}_${targetId}`;
  const author = environment.authenticatedContext(authorId, { email_verified: true }).firestore();
  const target = environment.authenticatedContext(targetId, { email_verified: true }).firestore();

  await assertSucceeds(setDoc(doc(author, "players", authorId), player(authorId, "Autor", "c")));
  await assertSucceeds(setDoc(doc(target, "players", targetId), player(targetId, "Destinatario", "c")));
  // Misma huella: es el patrón de alguien que se crea una segunda cuenta en su
  // propio móvil para inflarse los votos.
  await assertSucceeds(setDoc(doc(author, "users", authorId), { deviceHash: "hash-compartido" }));
  await assertSucceeds(setDoc(doc(target, "users", targetId), { deviceHash: "hash-compartido" }));
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "matches", matchId), {
      ...openMatch(authorId, ["c"]),
      acceptedByPlayerId: targetId,
      status: "accepted",
      resultStatus: "validated"
    });
  });

  const review = {
    id: reviewId,
    matchId,
    authorId,
    authorName: "Autor",
    targetId,
    targetName: "Destinatario",
    stars: 5,
    skillRatings: { consistency: 7, forehand: 8, backhand: 6, serve: 9, volley: 5 },
    comment: "Me voto a mí mismo.",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };

  await assertFails(setDoc(doc(author, "matchReviews", reviewId), review));

  // Desde otro teléfono la misma valoración sí entra.
  await assertSucceeds(setDoc(doc(target, "users", targetId), { deviceHash: "hash-distinto" }));
  await assertSucceeds(setDoc(doc(author, "matchReviews", reviewId), review));
});
