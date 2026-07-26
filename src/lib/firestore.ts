import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  setDoc,
  updateDoc,
  arrayUnion,
  arrayRemove,
  query,
  where,
  orderBy,
  onSnapshot,
  serverTimestamp,
  type QueryConstraint,
  type Unsubscribe
} from "@react-native-firebase/firestore";
import { db, isFirebaseConfigured } from "@/../firebase.config";
import { Club, Gender, MatchFormat, Player, PlayerProfileInput, SkillLevel, ValidatedRankingResult } from "@/types";

// ----------------------------------------------------------------------------
// Clubs (catálogo público). En el futuro vendrán de Firestore;
// mientras tanto usamos el seed local como fallback.
// ----------------------------------------------------------------------------
import { clubs as seedClubs, players as seedPlayers } from "@/data/seed";

let clubsCache: { value: Club[]; expiresAt: number } | null = null;
let playersCache: { value: Player[]; expiresAt: number } | null = null;

const MIN_VISIBLE_PLAYERS = 8;

/**
 * Completa la comunidad con perfiles inequívocamente demostrativos mientras
 * todavía hay pocos usuarios. Son objetos locales: nunca se escriben en
 * Firestore y `isDemo` desactiva cualquier interacción en la interfaz.
 */
function withDemoPlayers(realPlayers: Player[]): Player[] {
  if (realPlayers.length >= MIN_VISIBLE_PLAYERS) return realPlayers;
  const needed = MIN_VISIBLE_PLAYERS - realPlayers.length;
  const demos = seedPlayers
    .filter((player) => player.id !== "me")
    .slice(0, needed)
    .map((player) => ({
      ...player,
      id: `demo-${player.id}`,
      isDemo: true,
      profileComplete: true,
      responseRate: 0
    }));
  return [...realPlayers, ...demos];
}

export async function getClubs(): Promise<Club[]> {
  if (!isFirebaseConfigured) return seedClubs;
  if (clubsCache && clubsCache.expiresAt > Date.now()) return clubsCache.value;

  try {
    const snapshot = await getDocs(collection(db, "clubs"));
    if (snapshot.empty) return seedClubs;
    const remote = snapshot.docs.map((d) => d.data() as Club);
    const value = [...remote, ...seedClubs.filter((seed) => !remote.some((club) => club.id === seed.id))];
    clubsCache = { value, expiresAt: Date.now() + 10 * 60 * 1000 };
    return value;
  } catch (error) {
    console.warn("[matchpoint] getClubs: usando seed local", error);
    return seedClubs;
  }
}

/** Suscripción en tiempo real a los clubs (para futuras pantallas de administración). */
export function subscribeToClubs(onNext: (clubs: Club[]) => void): Unsubscribe {
  if (!isFirebaseConfigured) {
    onNext(seedClubs);
    return () => {};
  }
  return onSnapshot(collection(db, "clubs"), (snapshot) => {
    if (snapshot.empty) onNext(seedClubs);
    else {
      const remote = snapshot.docs.map((d) => d.data() as Club);
      onNext([...remote, ...seedClubs.filter((seed) => !remote.some((club) => club.id === seed.id))]);
    }
  });
}

// ----------------------------------------------------------------------------
// Players
// ----------------------------------------------------------------------------
const PLAYERS_COLLECTION = "players";

const LEGACY_LEVELS: Record<string, SkillLevel> = {
  beginner: "novato",
  intermediate: "d",
  advanced: "c",
  competitive: "b",
  novato: "novato",
  d: "d",
  c: "c",
  b: "b",
  a: "a"
};

/** Adapta perfiles del modelo anterior sin romper pantallas ni matching. */
export function normalizePlayerDocument(data: unknown, fallbackId?: string): Player {
  const raw = data as Partial<Player> & { clubId?: string; level?: string };
  const clubIds = Array.isArray(raw.clubIds) && raw.clubIds.length > 0
    ? raw.clubIds.filter((id): id is string => typeof id === "string")
    : raw.clubId
      ? [raw.clubId]
      : [];
  const level = LEGACY_LEVELS[String(raw.level ?? "novato").toLowerCase()] ?? "novato";
  const formats = Array.isArray(raw.preferredFormats)
    ? raw.preferredFormats.filter((format): format is MatchFormat => ["singles", "doubles", "mixed"].includes(String(format)))
    : [];
  const gender: Gender = raw.gender === "female" || raw.gender === "male" || raw.gender === "other"
    ? raw.gender
    : "other";
  const finiteNumber = (value: unknown, fallback: number) =>
    typeof value === "number" && Number.isFinite(value) ? value : fallback;
  return {
    ...(raw as Player),
    id: raw.id ?? fallbackId ?? "",
    name: typeof raw.name === "string" && raw.name.trim() ? raw.name.trim().slice(0, 80) : "Jugador MatchPoint",
    age: Math.min(100, Math.max(13, Math.round(finiteNumber(raw.age, 18)))),
    gender,
    clubIds,
    level,
    preferredFormats: formats.length > 0 ? formats : ["singles"],
    availability: Array.isArray(raw.availability) ? raw.availability : [],
    languages: Array.isArray(raw.languages) && raw.languages.length > 0
      ? raw.languages.filter((language): language is string => typeof language === "string").slice(0, 8)
      : ["Español"],
    city: typeof raw.city === "string" ? raw.city : "",
    country: typeof raw.country === "string" && raw.country ? raw.country : "Guatemala",
    latitude: finiteNumber(raw.latitude, 0),
    longitude: finiteNumber(raw.longitude, 0),
    bio: typeof raw.bio === "string" ? raw.bio.slice(0, 500) : "",
    rating: Math.min(5, Math.max(0, finiteNumber(raw.rating, 3))),
    responseRate: Math.min(100, Math.max(0, finiteNumber(raw.responseRate, 0)))
  };
}

export async function getPlayer(uid: string): Promise<Player | null> {
  if (!isFirebaseConfigured) return null;

  const snap = await getDoc(doc(db, PLAYERS_COLLECTION, uid));
  if (!snap.exists()) return null;
  return normalizePlayerDocument(snap.data(), snap.id);
}

/**
 * Inscribe al jugador en la liga pública de su rango (una por rango). La
 * pertenencia se guarda en su propio documento `players/{uid}` como array
 * `publicLeagues`; las reglas solo permiten al dueño modificarlo.
 */
export async function joinPublicLeague(uid: string, leagueId: string): Promise<void> {
  if (!isFirebaseConfigured) return;
  await updateDoc(doc(db, PLAYERS_COLLECTION, uid), {
    publicLeagues: arrayUnion(leagueId),
    updatedAt: serverTimestamp()
  });
}

/**
 * Inscritos reales de una liga pública. Se consultan por el array
 * `publicLeagues` del propio perfil, así que no hace falta una colección
 * aparte ni reglas nuevas. Nunca devuelve perfiles de muestra.
 */
export async function getPublicLeagueMembers(leagueId: string): Promise<Player[]> {
  if (!isFirebaseConfigured) return [];
  const snapshot = await getDocs(query(
    collection(db, PLAYERS_COLLECTION),
    where("publicLeagues", "array-contains", leagueId),
    limit(100)
  ));
  return snapshot.docs
    .map((d) => normalizePlayerDocument(d.data(), d.id))
    .filter((player) => player.isDemo !== true)
    .sort((a, b) => a.name.localeCompare(b.name));
}

export async function leavePublicLeague(uid: string, leagueId: string): Promise<void> {
  if (!isFirebaseConfigured) return;
  await updateDoc(doc(db, PLAYERS_COLLECTION, uid), {
    publicLeagues: arrayRemove(leagueId),
    updatedAt: serverTimestamp()
  });
}

/**
 * Crea o reemplaza el perfil deportivo del usuario autenticado.
 * Se invoca desde el onboarding o desde "editar perfil".
 */
export async function savePlayerProfile(uid: string, input: PlayerProfileInput): Promise<void> {
  if (!isFirebaseConfigured) {
    throw new Error("Firebase no está configurado. Revisa .env");
  }

  if (input.clubIds.length === 0) {
    throw new Error("Selecciona al menos un club habitual.");
  }

  const existing = await getDoc(doc(db, PLAYERS_COLLECTION, uid));
  const previous = existing.exists() ? normalizePlayerDocument(existing.data(), existing.id) : null;

  const allClubs = await getClubs();
  const primaryClub = allClubs.find((c) => c.id === input.clubIds[0]);
  if (!primaryClub) {
    throw new Error("El club principal no existe en el catálogo.");
  }

  const player: Player = {
    id: uid,
    ...input,
    // Si el usuario no especificó ciudad/país, derivamos del club principal.
    city: input.city?.trim() || primaryClub.city,
    country: input.country?.trim() || primaryClub.country,
    latitude: primaryClub.latitude,
    longitude: primaryClub.longitude,
    // Al editar el perfil nunca reiniciamos métricas competitivas.
    rating: previous?.rating ?? 3,
    responseRate: previous?.responseRate ?? 100,
    seekingTeam: previous?.seekingTeam ?? false,
    seekingTeamClubId: previous?.seekingTeam ? input.clubIds[0] : previous?.seekingTeamClubId,
    profileComplete: true
  };

  // Firestore no admite propiedades con valor `undefined`. Conservamos las
  // valoraciones previas salvo que el usuario envíe una autoevaluación nueva
  // desde el onboarding; sin ninguna de las dos, omitimos el campo.
  const skills = input.skills ?? previous?.skills;
  if (skills) player.skills = skills;

  if (!player.seekingTeamClubId) delete player.seekingTeamClubId;

  await setDoc(doc(db, PLAYERS_COLLECTION, uid), {
    ...player,
    updatedAt: serverTimestamp()
  }, { merge: true });
  playersCache = null;
}

export async function updatePlayerFields(uid: string, fields: Partial<Player>): Promise<void> {
  if (!isFirebaseConfigured) {
    throw new Error("Firebase no está configurado. Revisa .env");
  }
  await updateDoc(doc(db, PLAYERS_COLLECTION, uid), {
    ...fields,
    updatedAt: serverTimestamp()
  });
  playersCache = null;
}

export async function requestAndroidBetaAccess(uid: string, name: string, email: string | null): Promise<void> {
  if (!isFirebaseConfigured) throw new Error("Firebase no está configurado.");
  await setDoc(doc(db, "androidBetaRequests", uid), {
    userId: uid,
    name: name.trim().slice(0, 80),
    email: email?.trim().slice(0, 160) ?? "",
    status: "pending",
    requestedAt: serverTimestamp()
  }, { merge: true });
}

/** Suscripción en tiempo real al perfil del usuario autenticado. */
export function subscribeToPlayer(uid: string, onNext: (player: Player | null) => void, onError?: (error: Error) => void): Unsubscribe {
  if (!isFirebaseConfigured) {
    onNext(null);
    return () => {};
  }
  return onSnapshot(doc(db, PLAYERS_COLLECTION, uid), (snap) => {
    onNext(snap.exists() ? normalizePlayerDocument(snap.data(), snap.id) : null);
  }, (error) => onError?.(error));
}

/**
 * Lista todos los jugadores (para matching / búsqueda).
 * Filtra por criterios simples en cliente; el matching pesado va en `matching.ts`.
 */
export async function getAllPlayers(): Promise<Player[]> {
  if (!isFirebaseConfigured) {
    return withDemoPlayers(seedPlayers.map((player) => ({ ...player, profileComplete: true, isDemo: player.id !== "me" })));
  }
  if (playersCache && playersCache.expiresAt > Date.now()) return playersCache.value;

  try {
    const q = query(
      collection(db, PLAYERS_COLLECTION),
      where("profileComplete", "==", true),
      limit(100)
    );
    const snapshot = await getDocs(q);
    const value = withDemoPlayers(snapshot.docs.map((d) => normalizePlayerDocument(d.data(), d.id)));
    playersCache = { value, expiresAt: Date.now() + 20 * 1000 };
    return value;
  } catch (error) {
    console.warn("[matchpoint] getAllPlayers", error);
    throw new Error("No pudimos cargar los jugadores. Revisa tu conexión e inténtalo de nuevo.");
  }
}

/**
 * Devuelve un conjunto acotado de perfiles para descubrimiento/ranking.
 * La ciudad se filtra en Firestore para que abrir una pantalla no lea el
 * directorio mundial completo. El límite es además una defensa de cuota.
 */
export async function getPlayersForArea(city: string, division?: Player["level"]): Promise<Player[]> {
  if (!isFirebaseConfigured) {
    return withDemoPlayers(seedPlayers.map((player) => ({ ...player, profileComplete: true, isDemo: player.id !== "me" })))
      .filter((player) => !city || player.city === city)
      .filter((player) => !division || player.level === division);
  }
  const constraints: QueryConstraint[] = [
    where("profileComplete", "==", true),
    where("city", "==", city)
  ];
  if (division) constraints.push(where("level", "==", division));
  constraints.push(limit(100));
  const snapshot = await getDocs(query(collection(db, PLAYERS_COLLECTION), ...constraints));
  return snapshot.docs.map((item) => normalizePlayerDocument(item.data(), item.id));
}

export async function getValidatedRankingResults(city: string): Promise<ValidatedRankingResult[]> {
  if (!isFirebaseConfigured) return [];
  const snapshot = await getDocs(query(
    collection(db, "rankingResults"),
    where("city", "==", city),
    limit(500)
  ));
  return snapshot.docs.map((item) => ({ ...(item.data() as ValidatedRankingResult), matchId: item.id }));
}

/** Versión reactiva de getAllPlayers para futuras pantallas de ranking. */
export function subscribeToAllPlayers(onNext: (players: Player[]) => void): Unsubscribe {
  if (!isFirebaseConfigured) {
    onNext(withDemoPlayers(seedPlayers.map((player) => ({ ...player, profileComplete: true, isDemo: player.id !== "me" }))));
    return () => {};
  }

  const constraints: QueryConstraint[] = [where("profileComplete", "==", true), orderBy("rating", "desc"), limit(100)];
  return onSnapshot(query(collection(db, PLAYERS_COLLECTION), ...constraints), (snapshot) => {
    onNext(withDemoPlayers(snapshot.docs.map((d) => normalizePlayerDocument(d.data(), d.id))));
  });
}
