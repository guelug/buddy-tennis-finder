import {
  MatchReview,
  MatchRoom,
  MatchRoomStatus,
  PlayerSkills,
  SetScore,
  TeamSide
} from "@/types";
import { isFirebaseConfigured } from "@/../firebase.config";
import { auth, db } from "@/../firebase.config";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where
} from "firebase/firestore";

/**
 * Sala del partido — store del ciclo de vida de un partido jugado:
 *
 *   jugado → capitán registra marcador → un rival valida → cerrado → reseñas
 *
 * Reglas:
 *  - Solo un capitán puede registrar/corregir el resultado.
 *  - Valida cualquier jugador del equipo CONTRARIO al que reportó.
 *  - Reseñas: solo participantes, solo con el partido validado, máx. 1 por
 *    persona (se puede editar la propia).
 *
 * Hoy vive en memoria (mock). La forma de la API es async para que el swap a
 * Firestore sea 1:1.
 */

const LATENCY_MS = 220;

function wait() {
  return new Promise((resolve) => setTimeout(resolve, LATENCY_MS));
}

function daysAgo(days: number, hour = 19) {
  const date = new Date();
  date.setDate(date.getDate() - days);
  date.setHours(hour, 0, 0, 0);
  return date.toISOString();
}

// ---------------------------------------------------------------------------
// Seed — cubre todos los estados del flujo
// ---------------------------------------------------------------------------

const rooms: MatchRoom[] = [
  {
    // Falta resultado — el usuario es capitán: le toca registrarlo.
    id: "room-1",
    format: "singles",
    division: "c",
    clubId: "club-hercules",
    playedAt: daysAgo(1),
    teamA: { side: "A", playerIds: ["me"], playerNames: ["Ana Morales"], captainId: "me" },
    teamB: { side: "B", playerIds: ["p-1"], playerNames: ["Carlos Rivera"], captainId: "p-1" },
    status: "awaiting_result",
    reviews: []
  },
  {
    // Resultado reportado por el capitán rival — el usuario debe validar.
    id: "room-2",
    format: "doubles",
    division: "c",
    clubId: "club-sporta",
    playedAt: daysAgo(2, 20),
    teamA: {
      side: "A",
      playerIds: ["me", "p-2"],
      playerNames: ["Ana Morales", "María Fernanda López"],
      captainId: "p-2"
    },
    teamB: {
      side: "B",
      playerIds: ["p-3", "p-4"],
      playerNames: ["Diego Castillo", "Sofía Arévalo"],
      captainId: "p-3"
    },
    status: "awaiting_validation",
    result: {
      winner: "B",
      sets: [
        { a: 3, b: 6 },
        { a: 6, b: 4 },
        { a: 5, b: 7 }
      ],
      reportedById: "p-3",
      reportedByName: "Diego Castillo",
      reportedAt: daysAgo(1, 9)
    },
    reviews: []
  },
  {
    // Validado — falta la reseña del usuario.
    id: "room-3",
    format: "singles",
    division: "c",
    clubId: "club-hercules",
    playedAt: daysAgo(8),
    teamA: { side: "A", playerIds: ["me"], playerNames: ["Ana Morales"], captainId: "me" },
    teamB: { side: "B", playerIds: ["p-1"], playerNames: ["Carlos Rivera"], captainId: "p-1" },
    status: "validated",
    result: {
      winner: "A",
      sets: [
        { a: 6, b: 4 },
        { a: 7, b: 5 }
      ],
      reportedById: "me",
      reportedByName: "Ana Morales",
      reportedAt: daysAgo(7, 21)
    },
    validation: { playerId: "p-1", playerName: "Carlos Rivera", validatedAt: daysAgo(7, 22) },
    reviews: [
      {
        playerId: "p-1",
        playerName: "Carlos Rivera",
        stars: 5,
        skillRatings: { consistency: 9, forehand: 8, backhand: 8, serve: 9, volley: 7 },
        comment: "Partidazo. Ana defiende todo y el tercer set fue de infarto.",
        createdAt: daysAgo(7, 23)
      }
    ]
  },
  {
    // Validado con ambas reseñas — historial cerrado.
    id: "room-4",
    format: "singles",
    division: "c",
    clubId: "club-sporta",
    playedAt: daysAgo(21, 18),
    teamA: {
      side: "A",
      playerIds: ["p-2"],
      playerNames: ["María Fernanda López"],
      captainId: "p-2"
    },
    teamB: { side: "B", playerIds: ["me"], playerNames: ["Ana Morales"], captainId: "me" },
    status: "validated",
    result: {
      winner: "A",
      sets: [
        { a: 6, b: 2 },
        { a: 6, b: 3 }
      ],
      reportedById: "p-2",
      reportedByName: "María Fernanda López",
      reportedAt: daysAgo(20, 10)
    },
    validation: { playerId: "me", playerName: "Ana Morales", validatedAt: daysAgo(20, 12) },
    reviews: [
      {
        playerId: "me",
        playerName: "Ana Morales",
        stars: 4,
        skillRatings: { consistency: 8, forehand: 9, backhand: 8, serve: 9, volley: 8 },
        comment: "María saca durísimo, aprendí un montón. Revancha pendiente.",
        createdAt: daysAgo(20, 13)
      },
      {
        playerId: "p-2",
        playerName: "María Fernanda López",
        stars: 4,
        skillRatings: { consistency: 9, forehand: 8, backhand: 8, serve: 8, volley: 7 },
        comment: "Muy buen ritmo de peloteo, rival de las que te hacen mejorar.",
        createdAt: daysAgo(19, 9)
      }
    ]
  },
  {
    // Mixto validado — más notas para el perfil.
    id: "room-5",
    format: "mixed",
    division: "c",
    clubId: "club-antigua",
    playedAt: daysAgo(45, 10),
    teamA: { side: "A", playerIds: ["me"], playerNames: ["Ana Morales"], captainId: "me" },
    teamB: { side: "B", playerIds: ["p-3"], playerNames: ["Diego Castillo"], captainId: "p-3" },
    status: "validated",
    result: {
      winner: "A",
      sets: [
        { a: 7, b: 6 },
        { a: 6, b: 4 }
      ],
      reportedById: "me",
      reportedByName: "Ana Morales",
      reportedAt: daysAgo(44, 9)
    },
    validation: { playerId: "p-3", playerName: "Diego Castillo", validatedAt: daysAgo(44, 15) },
    reviews: [
      {
        playerId: "p-3",
        playerName: "Diego Castillo",
        stars: 4,
        skillRatings: { consistency: 8, forehand: 8, backhand: 9, serve: 8, volley: 8 },
        comment: "Puntual, buena onda y un revés cruzado que no vi venir.",
        createdAt: daysAgo(43, 8)
      },
      {
        playerId: "me",
        playerName: "Ana Morales",
        stars: 5,
        skillRatings: { consistency: 8, forehand: 8, backhand: 8, serve: 7, volley: 9 },
        comment: "El tie-break más divertido que he jugado este año.",
        createdAt: daysAgo(43, 10)
      }
    ]
  }
];

// ---------------------------------------------------------------------------
// Lectura
// ---------------------------------------------------------------------------

export async function getMatchRooms(playerId?: string): Promise<MatchRoom[]> {
  if (isFirebaseConfigured) return getFirebaseMatchRooms(playerId ?? auth.currentUser?.uid);
  await wait();
  const sorted = [...rooms].sort((a, b) => (a.playedAt > b.playedAt ? -1 : 1));
  if (!playerId) return sorted.map(cloneRoom);
  return sorted.filter((room) => isParticipant(room, playerId)).map(cloneRoom);
}

/** Reseñas que otros dejaron en partidos donde jugó `playerId` — sus "notas". */
export async function getReviewsForPlayer(playerId: string): Promise<MatchReview[]> {
  if (isFirebaseConfigured) return [];
  await wait();
  return rooms
    .filter((room) => isParticipant(room, playerId))
    .flatMap((room) => room.reviews)
    .filter((review) => review.playerId !== playerId)
    .sort((a, b) => (a.createdAt > b.createdAt ? -1 : 1))
    .map((review) => ({ ...review }));
}

// ---------------------------------------------------------------------------
// Mutaciones del flujo
// ---------------------------------------------------------------------------

export async function reportResult(
  roomId: string,
  playerId: string,
  input: { winner: TeamSide; sets: SetScore[] }
): Promise<MatchRoom> {
  if (isFirebaseConfigured) {
    const room = await getFirebaseRoom(roomId);
    if (!roomAffordances(room, playerId).canReport) throw new Error("Solo un participante puede registrar el resultado.");
    if (!validSets(input.sets)) throw new Error("El marcador no es válido.");
    await updateDoc(doc(db, "matches", roomId), {
      resultStatus: "awaiting_validation",
      result: {
        winner: input.winner,
        sets: input.sets,
        reportedById: playerId,
        reportedByName: nameOf(room, playerId),
        reportedAt: new Date().toISOString()
      },
      updatedAt: serverTimestamp()
    });
    return getFirebaseRoom(roomId);
  }
  await wait();
  const room = requireRoom(roomId);
  const affordances = roomAffordances(room, playerId);
  if (!affordances.canReport) {
    throw new Error("Solo el capitán puede registrar el resultado.");
  }
  if (input.sets.length === 0) {
    throw new Error("Registra al menos un set.");
  }
  room.result = {
    winner: input.winner,
    sets: input.sets.map((set) => ({ ...set })),
    reportedById: playerId,
    reportedByName: nameOf(room, playerId),
    reportedAt: new Date().toISOString()
  };
  room.status = "awaiting_validation";
  return cloneRoom(room);
}

export async function validateResult(roomId: string, playerId: string): Promise<MatchRoom> {
  if (isFirebaseConfigured) {
    const room = await getFirebaseRoom(roomId);
    if (!roomAffordances(room, playerId).canValidate || !room.result) {
      throw new Error("Solo el rival puede validar este resultado.");
    }
    const matchRef = doc(db, "matches", roomId);
    const rankingRef = doc(db, "rankingResults", roomId);
    await runTransaction(db, async (transaction) => {
      const fresh = await transaction.get(matchRef);
      const data = fresh.data();
      if (!fresh.exists() || data?.resultStatus !== "awaiting_validation" || data.result?.reportedById === playerId) {
        throw new Error("El resultado ya cambió o no te corresponde validarlo.");
      }
      transaction.update(matchRef, {
        resultStatus: "validated",
        validation: {
          playerId,
          playerName: nameOf(room, playerId),
          validatedAt: new Date().toISOString()
        },
        updatedAt: serverTimestamp()
      });
      transaction.set(rankingRef, {
        matchId: roomId,
        city: String(data.city || ""),
        division: data.division,
        playerAId: data.fromPlayerId,
        playerBId: data.acceptedByPlayerId,
        winnerId: data.result.winner === "A" ? data.fromPlayerId : data.acceptedByPlayerId,
        playedAt: data.startsAt,
        validatedById: playerId,
        createdAt: serverTimestamp()
      });
    });
    return getFirebaseRoom(roomId);
  }
  await wait();
  const room = requireRoom(roomId);
  if (!roomAffordances(room, playerId).canValidate) {
    throw new Error("Solo un jugador del equipo rival puede validar.");
  }
  room.status = "validated";
  room.validation = {
    playerId,
    playerName: nameOf(room, playerId),
    validatedAt: new Date().toISOString()
  };
  return cloneRoom(room);
}

export async function disputeResult(roomId: string, playerId: string): Promise<MatchRoom> {
  if (isFirebaseConfigured) {
    const room = await getFirebaseRoom(roomId);
    if (!roomAffordances(room, playerId).canValidate) throw new Error("Solo el rival puede disputar este resultado.");
    await updateDoc(doc(db, "matches", roomId), {
      resultStatus: "disputed",
      updatedAt: serverTimestamp()
    });
    return getFirebaseRoom(roomId);
  }
  await wait();
  const room = requireRoom(roomId);
  if (!roomAffordances(room, playerId).canValidate) {
    throw new Error("Solo un jugador del equipo rival puede disputar.");
  }
  room.status = "disputed";
  return cloneRoom(room);
}

export async function submitReview(
  roomId: string,
  playerId: string,
  input: { stars: number; comment: string; skillRatings: PlayerSkills }
): Promise<MatchRoom> {
  requireDemoMode();
  await wait();
  const room = requireRoom(roomId);
  if (room.status !== "validated") {
    throw new Error("Las reseñas se abren cuando el resultado está validado.");
  }
  if (!isParticipant(room, playerId)) {
    throw new Error("Solo quienes jugaron el partido pueden dejar reseña.");
  }
  const review: MatchReview = {
    playerId,
    playerName: nameOf(room, playerId),
    stars: Math.min(5, Math.max(1, Math.round(input.stars))),
    skillRatings: {
      consistency: clampSkill(input.skillRatings.consistency),
      forehand: clampSkill(input.skillRatings.forehand),
      backhand: clampSkill(input.skillRatings.backhand),
      serve: clampSkill(input.skillRatings.serve),
      volley: clampSkill(input.skillRatings.volley)
    },
    comment: input.comment.trim().slice(0, 180),
    createdAt: new Date().toISOString()
  };
  // Máx. una reseña por participante: reemplaza la propia si ya existía.
  room.reviews = [...room.reviews.filter((r) => r.playerId !== playerId), review];
  return cloneRoom(room);
}

function clampSkill(value: number) {
  return Math.min(10, Math.max(1, Math.round(value * 10) / 10));
}

function requireDemoMode() {
  if (isFirebaseConfigured) {
    throw new Error("El registro de resultados estará disponible en la siguiente fase beta.");
  }
}

function validSets(sets: SetScore[]) {
  return sets.length >= 1 && sets.length <= 5 && sets.every((set) =>
    Number.isInteger(set.a) && Number.isInteger(set.b)
    && set.a >= 0 && set.a <= 99 && set.b >= 0 && set.b <= 99 && set.a !== set.b
  );
}

async function getFirebaseMatchRooms(playerId?: string): Promise<MatchRoom[]> {
  if (!playerId) return [];
  const [owned, joined] = await Promise.all([
    getDocs(query(collection(db, "matches"), where("fromPlayerId", "==", playerId))),
    getDocs(query(collection(db, "matches"), where("acceptedByPlayerId", "==", playerId)))
  ]);
  const matches = new Map([...owned.docs, ...joined.docs].map((item) => [item.id, item]));
  const result = await Promise.all(Array.from(matches.values()).map(async (item): Promise<MatchRoom | null> => {
    const data = item.data();
    if (data.status !== "accepted" || !data.acceptedByPlayerId || new Date(data.startsAt).getTime() > Date.now()) return null;
    const [owner, rival] = await Promise.all([
      getDoc(doc(db, "players", data.fromPlayerId)),
      getDoc(doc(db, "players", data.acceptedByPlayerId))
    ]);
    const ownerName = String(owner.data()?.name || "Jugador");
    const rivalName = String(rival.data()?.name || "Rival");
    return {
      id: item.id,
      format: data.format,
      division: data.division,
      clubId: data.clubId,
      playedAt: data.startsAt,
      teamA: { side: "A", playerIds: [data.fromPlayerId], playerNames: [ownerName], captainId: data.fromPlayerId },
      teamB: { side: "B", playerIds: [data.acceptedByPlayerId], playerNames: [rivalName], captainId: data.acceptedByPlayerId },
      status: (data.resultStatus || "awaiting_result") as MatchRoomStatus,
      result: data.result,
      validation: data.validation,
      reviews: []
    } satisfies MatchRoom;
  }));
  return result.filter((room): room is MatchRoom => room !== null)
    .sort((a, b) => b.playedAt.localeCompare(a.playedAt));
}

async function getFirebaseRoom(roomId: string): Promise<MatchRoom> {
  const playerId = auth.currentUser?.uid;
  const roomsForPlayer = await getFirebaseMatchRooms(playerId);
  const room = roomsForPlayer.find((item) => item.id === roomId);
  if (!room) throw new Error("No encontramos este partido o todavía no se ha jugado.");
  return room;
}

// ---------------------------------------------------------------------------
// Helpers puros para la UI
// ---------------------------------------------------------------------------

export type RoomAffordances = {
  side: TeamSide | null;
  isCaptain: boolean;
  /** Puede registrar (o corregir en disputa) el marcador. */
  canReport: boolean;
  /** Puede confirmar/disputar el resultado reportado por el rival. */
  canValidate: boolean;
  /** Puede dejar (o editar) su reseña. */
  canReview: boolean;
  myReview: MatchReview | null;
  /** Acción pendiente que le toca a este jugador (para badges/CTAs). */
  pendingAction: "report" | "validate" | "review" | null;
};

export function roomAffordances(room: MatchRoom, playerId?: string): RoomAffordances {
  const side = playerId
    ? room.teamA.playerIds.includes(playerId)
      ? ("A" as const)
      : room.teamB.playerIds.includes(playerId)
        ? ("B" as const)
        : null
    : null;
  const team = side === "A" ? room.teamA : side === "B" ? room.teamB : null;
  const isCaptain = !!playerId && !!team && team.captainId === playerId;

  const canReport =
    isCaptain && (room.status === "awaiting_result" || room.status === "disputed");

  const reporterSide: TeamSide | null = room.result
    ? room.teamA.playerIds.includes(room.result.reportedById)
      ? "A"
      : "B"
    : null;
  const canValidate =
    room.status === "awaiting_validation" && !!side && !!reporterSide && side !== reporterSide;

  const myReview = playerId
    ? (room.reviews.find((review) => review.playerId === playerId) ?? null)
    : null;
  const canReview = room.status === "validated" && !!side;

  const pendingAction = canReport
    ? ("report" as const)
    : canValidate
      ? ("validate" as const)
      : canReview && !myReview
        ? ("review" as const)
        : null;

  return { side, isCaptain, canReport, canValidate, canReview, myReview, pendingAction };
}

export function averageStars(reviews: MatchReview[]): number | null {
  if (reviews.length === 0) return null;
  return reviews.reduce((sum, review) => sum + review.stars, 0) / reviews.length;
}

export function scoreLine(room: MatchRoom): string | null {
  if (!room.result) return null;
  return room.result.sets.map((set) => `${set.a}-${set.b}`).join("  ");
}

function isParticipant(room: MatchRoom, playerId: string) {
  return room.teamA.playerIds.includes(playerId) || room.teamB.playerIds.includes(playerId);
}

function nameOf(room: MatchRoom, playerId: string): string {
  const indexA = room.teamA.playerIds.indexOf(playerId);
  if (indexA >= 0) return room.teamA.playerNames[indexA];
  const indexB = room.teamB.playerIds.indexOf(playerId);
  if (indexB >= 0) return room.teamB.playerNames[indexB];
  return "Jugador";
}

function requireRoom(roomId: string): MatchRoom {
  const room = rooms.find((item) => item.id === roomId);
  if (!room) throw new Error("Partido no encontrado.");
  return room;
}

function cloneRoom(room: MatchRoom): MatchRoom {
  return {
    ...room,
    teamA: { ...room.teamA, playerIds: [...room.teamA.playerIds], playerNames: [...room.teamA.playerNames] },
    teamB: { ...room.teamB, playerIds: [...room.teamB.playerIds], playerNames: [...room.teamB.playerNames] },
    result: room.result
      ? { ...room.result, sets: room.result.sets.map((set) => ({ ...set })) }
      : undefined,
    validation: room.validation ? { ...room.validation } : undefined,
    reviews: room.reviews.map((review) => ({
      ...review,
      skillRatings: review.skillRatings ? { ...review.skillRatings } : undefined
    }))
  };
}
