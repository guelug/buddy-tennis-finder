import { MatchProposal, SearchPreferences, Player, Club, MatchCandidate, MatchJoinRequest } from "../types";
import {
  createProposal as createMockProposal,
  getHomeData as getMockHomeData,
  updateProposalStatus as updateMockProposalStatus
} from "./mock-api";
import { isFirebaseConfigured, auth, db } from "@/../firebase.config";
import {
  collection,
  addDoc,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where
} from "firebase/firestore";
import { getClubs, getPlayersForArea, getPlayer, normalizePlayerDocument } from "./firestore";
import { isLevelCompatible, rankCandidates } from "./matching";

export type HomeData = {
  currentPlayer: Player;
  players: Player[];
  clubs: Club[];
  candidates: MatchCandidate[];
  proposals: MatchProposal[];
  joinRequests: MatchJoinRequest[];
};

function readCurrentProposal(id: string, data: unknown): MatchProposal | null {
  const raw = data as Partial<MatchProposal> & { toPlayerId?: string };
  // Las invitaciones dirigidas antiguas carecen de reserva concreta y no se
  // convierten en públicas desde el cliente. El migrador las archiva.
  if (
    !("acceptedByPlayerId" in raw)
    || (raw.acceptedByPlayerId !== null && typeof raw.acceptedByPlayerId !== "string")
    || typeof raw.fromPlayerId !== "string"
    || typeof raw.clubId !== "string"
    || typeof raw.startsAt !== "string"
    || !Number.isFinite(new Date(raw.startsAt).getTime())
    || typeof raw.reservationTime !== "string"
    || typeof raw.court !== "number"
    || !Number.isInteger(raw.court)
    || !["proposed", "accepted", "declined"].includes(String(raw.status))
    // El flujo actual necesita exactamente dos participantes. Las propuestas
    // antiguas de dobles/mixto se ocultan hasta que exista gestión de equipos.
    || raw.format !== "singles"
    || !["novato", "d", "c", "b", "a"].includes(String(raw.division))
  ) {
    return null;
  }
  return {
    ...(raw as MatchProposal),
    id: raw.id || id,
    message: typeof raw.message === "string" ? raw.message.slice(0, 280) : "",
    proposedAt: typeof raw.proposedAt === "string" ? raw.proposedAt : raw.startsAt,
    acceptedLevels: Array.isArray(raw.acceptedLevels)
      ? raw.acceptedLevels.filter((level): level is MatchProposal["division"] => ["novato", "d", "c", "b", "a"].includes(String(level)))
      : [raw.division as MatchProposal["division"]]
  };
}

function readJoinRequest(id: string, data: unknown): MatchJoinRequest | null {
  const raw = data as Partial<MatchJoinRequest>;
  if (
    typeof raw.matchId !== "string"
    || typeof raw.ownerId !== "string"
    || typeof raw.requesterId !== "string"
    || typeof raw.requesterName !== "string"
    || !["novato", "d", "c", "b", "a"].includes(String(raw.requesterLevel))
    || !["pending", "accepted", "declined"].includes(String(raw.status))
  ) return null;
  return {
    id,
    matchId: raw.matchId,
    ownerId: raw.ownerId,
    requesterId: raw.requesterId,
    requesterName: raw.requesterName.slice(0, 80),
    requesterLevel: raw.requesterLevel as MatchJoinRequest["requesterLevel"],
    status: raw.status as MatchJoinRequest["status"],
    createdAt: typeof raw.createdAt === "string" ? raw.createdAt : ""
  };
}

async function getJoinRequests(uid: string): Promise<MatchJoinRequest[]> {
  if (!isFirebaseConfigured) return [];
  let owned;
  let requested;
  try {
    [owned, requested] = await Promise.all([
      getDocs(query(collection(db, "matchJoinRequests"), where("ownerId", "==", uid))),
      getDocs(query(collection(db, "matchJoinRequests"), where("requesterId", "==", uid)))
    ]);
  } catch (error) {
    // Compatibilidad durante un rollout: la app sigue cargando aunque las
    // reglas nuevas todavía no hayan llegado al proyecto.
    console.warn("[matchpoint] matchJoinRequests no disponible", error);
    return [];
  }
  const merged = new Map<string, MatchJoinRequest>();
  for (const snapshot of [owned, requested]) {
    for (const item of snapshot.docs) {
      const request = readJoinRequest(item.id, item.data());
      if (request) merged.set(request.id, request);
    }
  }
  return Array.from(merged.values());
}

/** Normaliza ciudad/país para comparar texto libre de perfiles antiguos. */
export function normalizeArea(value: string | undefined | null): string {
  return (value ?? "").trim().toLocaleLowerCase("es").normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

export async function getHomeData(
  preferences?: SearchPreferences,
  currentUserId?: string
): Promise<HomeData> {
  // Sin Firebase configurado: usamos el mock con datos semilla.
  if (!isFirebaseConfigured) {
    const mock = await getMockHomeData(preferences);
    return { ...mock, joinRequests: [] };
  }

  const uid = currentUserId ?? auth.currentUser?.uid;
  if (!uid) {
    throw new Error("No hay sesión activa.");
  }

  // propuestasPropias: las que yo creé o las que yo acepté.
  // propuestasAbiertas: las publicadas por otros y que nadie ha aceptado aún.
  const playerSnap = await withTimeout(
    getDoc(doc(db, "players", uid)),
    12000,
    "La conexión está tardando demasiado. Comprueba internet y vuelve a intentarlo."
  );
  const currentPlayer = playerSnap.exists() ? normalizePlayerDocument(playerSnap.data(), playerSnap.id) : null;
  if (!currentPlayer) {
    throw new Error("Perfil no encontrado. Completa el onboarding.");
  }

  const [clubs, allPlayers, mineSnap, acceptedSnap, openSnap, joinRequests] = await withTimeout(Promise.all([
    getClubs(),
    getPlayersForArea(currentPlayer.city),
    getDocs(query(collection(db, "matches"), where("fromPlayerId", "==", uid))),
    getDocs(query(collection(db, "matches"), where("acceptedByPlayerId", "==", uid))),
    getDocs(
      query(
        collection(db, "matches"),
        where("acceptedByPlayerId", "==", null),
        where("status", "==", "proposed"),
        where("city", "==", currentPlayer.city)
      )
    ),
    getJoinRequests(uid)
  ]), 12000, "La conexión está tardando demasiado. Comprueba internet y vuelve a intentarlo.");

  const otherPlayers = allPlayers.filter((p) => p.id !== uid);
  const candidates = rankCandidates(currentPlayer, otherPlayers, preferences ?? defaultPreferences);

  // Combino propias, aceptadas y abiertas, descartando duplicados por id.
  const seen = new Set<string>();
  const proposals: MatchProposal[] = [];
  for (const snap of [mineSnap, acceptedSnap, openSnap]) {
    for (const docSnap of snap.docs) {
      if (seen.has(docSnap.id)) continue;
      seen.add(docSnap.id);
      const proposal = readCurrentProposal(docSnap.id, docSnap.data());
      if (proposal) proposals.push(proposal);
    }
  }
  // La consulta de propuestas abiertas no está acotada por región, así que
  // llegaban partidos de cualquier país. Resolvemos la ciudad a partir del
  // club de la reserva: un partido solo es jugable si es en tu ciudad.
  const cityOfClub = new Map(clubs.map((club) => [club.id, normalizeArea(club.city)]));
  const myCity = normalizeArea(currentPlayer.city);
  const isNearby = (proposal: MatchProposal) => {
    const proposalCity = cityOfClub.get(proposal.clubId);
    // Sin ciudad conocida (club retirado del catálogo) no ocultamos el partido:
    // el creador y quien lo aceptó siempre deben poder verlo.
    if (!proposalCity || !myCity) return true;
    return proposalCity === myCity;
  };

  const visibleProposals = proposals.filter((proposal) =>
    proposal.fromPlayerId === uid
    || proposal.acceptedByPlayerId === uid
    || (
      proposal.acceptedByPlayerId === null
      && proposal.status === "proposed"
      && new Date(proposal.startsAt).getTime() > Date.now()
      && isNearby(proposal)
      && (proposal.acceptedLevels?.includes(currentPlayer.level) ?? isLevelCompatible(proposal.division, currentPlayer.level))
    )
  );
  visibleProposals.sort((a, b) => (a.proposedAt > b.proposedAt ? -1 : 1));

  return { currentPlayer, players: allPlayers, clubs, candidates, proposals: visibleProposals, joinRequests };
}

export async function createProposal(
  input: Omit<MatchProposal, "id" | "fromPlayerId" | "proposedAt" | "status" | "acceptedByPlayerId">,
  fromPlayerId?: string
) {
  if (!isFirebaseConfigured) {
    return createMockProposal(input);
  }

  const uid = fromPlayerId ?? auth.currentUser?.uid;
  if (!uid) throw new Error("No hay sesión activa.");

  const [clubs, player, existingSnap] = await Promise.all([
    getClubs(),
    getPlayer(uid),
    getDocs(query(collection(db, "matches"), where("fromPlayerId", "==", uid)))
  ]);
  if (!player?.profileComplete) throw new Error("Completa tu perfil antes de publicar un partido.");
  const club = clubs.find((item) => item.id === input.clubId);
  if (!club) throw new Error("El club seleccionado no existe.");
  if (!Number.isInteger(input.court) || input.court < 1 || input.court > club.courts) {
    throw new Error(`La cancha debe estar entre 1 y ${club.courts}.`);
  }
  const startMs = new Date(input.startsAt).getTime();
  if (!Number.isFinite(startMs) || startMs < Date.now() + 5 * 60 * 1000) {
    throw new Error("La reserva debe tener una fecha futura válida.");
  }
  if (!isValidReservationTime(input.reservationTime)) {
    throw new Error("El horario de la reserva no es válido.");
  }
  if (input.format !== "singles") {
    throw new Error("Las reservas de dobles y mixto se activarán junto con el flujo de equipos.");
  }
  const duplicate = existingSnap.docs.some((snapshot) => {
    const existing = snapshot.data() as Partial<MatchProposal>;
    return existing.status !== "declined"
      && existing.clubId === input.clubId
      && existing.court === input.court
      && existing.startsAt === input.startsAt;
  });
  if (duplicate) throw new Error("Ya publicaste esta misma reserva.");

  const payload = {
    ...input,
    division: player.level,
    acceptedLevels: input.acceptedLevels?.length ? Array.from(new Set(input.acceptedLevels)) : [player.level],
    message: input.message.trim().slice(0, 280),
    fromPlayerId: uid,
    acceptedByPlayerId: null,
    status: "proposed" as const,
    proposedAt: new Date().toISOString(),
    createdAt: serverTimestamp()
    ,city: club.city
  };

  const ref = await addDoc(collection(db, "matches"), payload);
  return { ...payload, id: ref.id } as MatchProposal;
}

export async function requestMatchJoin(matchId: string): Promise<MatchJoinRequest> {
  if (!isFirebaseConfigured) throw new Error("Las solicitudes no están disponibles en modo demo.");
  const uid = auth.currentUser?.uid;
  if (!uid) throw new Error("No hay sesión activa.");
  const requestId = `${matchId}_${uid}`;
  const requestRef = doc(db, "matchJoinRequests", requestId);
  const [matchSnapshot, player, existingRequestSnapshot] = await Promise.all([
    getDoc(doc(db, "matches", matchId)),
    getPlayer(uid),
    getDoc(requestRef)
  ]);
  if (!matchSnapshot.exists()) throw new Error("Este partido ya no existe.");
  if (!player || player.isDemo) throw new Error("Completa tu perfil antes de solicitar plaza.");
  const proposal = readCurrentProposal(matchSnapshot.id, matchSnapshot.data());
  if (!proposal || proposal.status !== "proposed" || proposal.acceptedByPlayerId !== null) throw new Error("La plaza ya no está disponible.");
  if (proposal.fromPlayerId === uid) throw new Error("Ya eres quien organiza este partido.");
  if (!(proposal.acceptedLevels?.includes(player.level) ?? isLevelCompatible(proposal.division, player.level))) {
    throw new Error("Tu nivel no está entre los aceptados por el organizador.");
  }
  const createdAt = new Date().toISOString();
  const request: MatchJoinRequest = {
    id: requestId,
    matchId,
    ownerId: proposal.fromPlayerId,
    requesterId: uid,
    requesterName: player.name,
    requesterLevel: player.level,
    status: "pending",
    createdAt
  };

  if (existingRequestSnapshot.exists()) {
    const existingRequest = readJoinRequest(existingRequestSnapshot.id, existingRequestSnapshot.data());
    if (!existingRequest) throw new Error("La solicitud anterior no tiene un formato válido.");
    if (existingRequest.status === "pending") return existingRequest;
    if (existingRequest.status === "accepted") throw new Error("Tu plaza ya fue aceptada.");
    await updateDoc(requestRef, {
      status: "pending",
      createdAt,
      createdAtServer: serverTimestamp(),
      updatedAt: serverTimestamp()
    });
    return request;
  }

  await setDoc(requestRef, { ...request, createdAtServer: serverTimestamp() });
  return request;
}

export async function respondToMatchJoinRequest(request: MatchJoinRequest, accept: boolean) {
  if (!isFirebaseConfigured) throw new Error("Las solicitudes no están disponibles en modo demo.");
  const uid = auth.currentUser?.uid;
  if (!uid || uid !== request.ownerId) throw new Error("Solo el organizador puede responder.");
  const matchRef = doc(db, "matches", request.matchId);
  const requestRef = doc(db, "matchJoinRequests", request.id);
  return runTransaction(db, async (transaction) => {
    const [matchSnapshot, requestSnapshot] = await Promise.all([transaction.get(matchRef), transaction.get(requestRef)]);
    if (!matchSnapshot.exists() || !requestSnapshot.exists()) throw new Error("La solicitud ya no está disponible.");
    const proposal = readCurrentProposal(matchSnapshot.id, matchSnapshot.data());
    const currentRequest = readJoinRequest(requestSnapshot.id, requestSnapshot.data());
    if (!proposal || !currentRequest || currentRequest.status !== "pending") throw new Error("La solicitud ya fue procesada.");
    if (accept) {
      if (proposal.status !== "proposed" || proposal.acceptedByPlayerId !== null) throw new Error("La plaza ya fue asignada.");
      transaction.update(matchRef, { acceptedByPlayerId: currentRequest.requesterId, status: "accepted", updatedAt: serverTimestamp() });
    }
    transaction.update(requestRef, { status: accept ? "accepted" : "declined", updatedAt: serverTimestamp() });
  });
}

export async function updateProposalStatus(id: string, status: MatchProposal["status"]) {
  if (!isFirebaseConfigured) {
    return updateMockProposalStatus(id, status);
  }

  const uid = auth.currentUser?.uid;
  if (!uid) throw new Error("No hay sesión activa.");
  const matchRef = doc(db, "matches", id);

  return runTransaction(db, async (transaction) => {
    const snapshot = await transaction.get(matchRef);
    if (!snapshot.exists()) throw new Error("La propuesta ya no existe.");
    const proposal = readCurrentProposal(snapshot.id, snapshot.data());
    if (!proposal) throw new Error("La propuesta usa un formato antiguo y no puede modificarse.");

    if (status === "accepted") {
      if (proposal.fromPlayerId === uid) throw new Error("No puedes aceptar tu propia propuesta.");
      if (proposal.status !== "proposed" || proposal.acceptedByPlayerId !== null) {
        throw new Error("Otro jugador ya aceptó esta reserva.");
      }
      if (new Date(proposal.startsAt).getTime() <= Date.now()) {
        throw new Error("Esta reserva ya ha comenzado o caducó.");
      }
      const playerSnapshot = await transaction.get(doc(db, "players", uid));
      if (!playerSnapshot.exists()) throw new Error("Completa tu perfil antes de aceptar.");
      const player = normalizePlayerDocument(playerSnapshot.data(), playerSnapshot.id);
      if (!isLevelCompatible(proposal.division, player.level)) {
        throw new Error("Tu nivel no es compatible con esta propuesta.");
      }
      transaction.update(matchRef, {
        acceptedByPlayerId: uid,
        status: "accepted",
        updatedAt: serverTimestamp()
      });
      return { ...proposal, acceptedByPlayerId: uid, status: "accepted" as const };
    }

    if (status === "declined") {
      if (proposal.fromPlayerId !== uid) throw new Error("Solo quien publicó la reserva puede cancelarla.");
      if (proposal.status === "declined") return proposal;
      transaction.update(matchRef, { status: "declined", updatedAt: serverTimestamp() });
      return { ...proposal, status: "declined" as const };
    }

    if (status === "proposed") {
      if (proposal.status !== "accepted" || proposal.acceptedByPlayerId !== uid) {
        throw new Error("Solo quien aceptó el partido puede liberar la plaza.");
      }
      if (new Date(proposal.startsAt).getTime() <= Date.now()) {
        throw new Error("No se puede reabrir una reserva que ya comenzó.");
      }
      transaction.update(matchRef, {
        acceptedByPlayerId: null,
        status: "proposed",
        updatedAt: serverTimestamp()
      });
      return { ...proposal, acceptedByPlayerId: null, status: "proposed" as const };
    }

    throw new Error("Cambio de estado no permitido.");
  });
}

/**
 * Suscripción en tiempo real a los partidos donde participa el usuario:
 * los que creó, los que aceptó y las propuestas abiertas de otros.
 * Firestore no soporta OR en una sola query simple, así que abrimos varias
 * suscripciones y combinamos los resultados.
 */
export function subscribeToProposals(
  uid: string,
  onNext: (proposals: MatchProposal[]) => void
) {
  if (!isFirebaseConfigured) return () => {};

  const mine = new Map<string, MatchProposal>();
  const accepted = new Map<string, MatchProposal>();
  const open = new Map<string, MatchProposal>();

  const emit = () => {
    const merged = new Map<string, MatchProposal>([...mine, ...accepted, ...open]);
    const proposals = Array.from(merged.values());
    proposals.sort((a, b) => (a.proposedAt > b.proposedAt ? -1 : 1));
    onNext(proposals);
  };

  const unsubs = [
    onSnapshot(query(collection(db, "matches"), where("fromPlayerId", "==", uid)), (snapshot) => {
      mine.clear();
      for (const docSnap of snapshot.docs) {
        const proposal = readCurrentProposal(docSnap.id, docSnap.data());
        if (proposal) mine.set(docSnap.id, proposal);
      }
      emit();
    }),
    onSnapshot(query(collection(db, "matches"), where("acceptedByPlayerId", "==", uid)), (snapshot) => {
      accepted.clear();
      for (const docSnap of snapshot.docs) {
        const proposal = readCurrentProposal(docSnap.id, docSnap.data());
        if (proposal) accepted.set(docSnap.id, proposal);
      }
      emit();
    }),
    onSnapshot(
      query(
        collection(db, "matches"),
        where("acceptedByPlayerId", "==", null),
        where("status", "==", "proposed")
      ),
      (snapshot) => {
        open.clear();
        for (const docSnap of snapshot.docs) {
          const proposal = readCurrentProposal(docSnap.id, docSnap.data());
          if (!proposal) continue;
          // Solo propuestas de otros (las mías ya entran por la suscripción de fromPlayerId).
          if (proposal.fromPlayerId !== uid) open.set(docSnap.id, proposal);
        }
        emit();
      }
    )
  ];

  return () => unsubs.forEach((u) => u());
}

const defaultPreferences: SearchPreferences = {
  level: "any",
  formats: ["singles", "mixed"],
  ageMin: 18,
  ageMax: 65,
  requireSharedAvailability: true
};

function isValidReservationTime(value: string) {
  const match = /^([01]\d|2[0-3]):([0-5]\d)-([01]\d|2[0-3]):([0-5]\d)$/.exec(value);
  if (!match) return false;
  const [, startHour, startMinute, endHour, endMinute] = match;
  const start = Number(startHour) * 60 + Number(startMinute);
  const end = Number(endHour) * 60 + Number(endMinute);
  return end > start;
}

function withTimeout<T>(promise: Promise<T>, milliseconds: number, message: string): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(message)), milliseconds);
    promise.then(
      (value) => { clearTimeout(timer); resolve(value); },
      (error) => { clearTimeout(timer); reject(error); }
    );
  });
}
