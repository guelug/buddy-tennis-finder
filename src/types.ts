/** Nivel de juego. Orden de menor a mayor: novato < D < C < B < A. */
export type SkillLevel = "novato" | "d" | "c" | "b" | "a";

/** División de liga — alias de nivel de juego. */
export type Division = SkillLevel;

export type RankTier = "bronce" | "plata" | "oro" | "platino" | "elite";

export type RankingEntry = {
  rank: number;
  playerId: string;
  playerName: string;
  division: Division;
  tier: RankTier;
  points: number;
  wins: number;
  losses: number;
  streak: number;
  clubName?: string;
  /** Ciudad y país del jugador — permiten filtrar el ranking por región. */
  city?: string;
  country?: string;
  isDemo?: boolean;
};

/** Fila del ranking de dobles: la unidad clasificada es la pareja. */
export type DoublesRankingEntry = {
  rank: number;
  /** Ids de los dos jugadores, siempre ordenados: identifica a la pareja. */
  pairId: string;
  playerIds: string[];
  playerNames: string[];
  division: Division;
  points: number;
  wins: number;
  losses: number;
  /** Partidos jugados juntos: premia a quien repite compañero. */
  played: number;
  city?: string;
};

export type ValidatedRankingResult = {
  matchId: string;
  city: string;
  division: Division;
  playerAId: string;
  playerBId: string;
  winnerId: string;
  playedAt: string;
};

/**
 * Resultado validado de un partido de dobles. Va en su propia colección
 * (`doublesRankingResults`) porque una victoria en dobles no dice lo mismo que
 * una en individuales y no debe mezclarse en la misma clasificación.
 *
 * Ojo: esto separa SOLO el histórico de victorias. Las valoraciones (estrellas
 * y las notas de 1 a 10 por golpe) siguen en una única bolsa `matchReviews` y
 * alimentan el perfil y el radar de la persona venga de donde venga el
 * partido — no existe un "nivel técnico de dobles" aparte.
 *
 * La clasificación se construye por PAREJA, no por jugador: dos personas que
 * repiten compañero acumulan histórico juntas, que es justo lo que queremos
 * premiar.
 */
export type DoublesRankingResult = {
  matchId: string;
  city: string;
  division: Division;
  teamAIds: string[];
  teamBIds: string[];
  winnerTeam: TeamSide;
  playedAt: string;
};

export type MatchStatus = "proposed" | "accepted" | "declined";

export type MatchFormat = "singles" | "doubles" | "mixed";

export type PlayedMatch = {
  id: string;
  playerAId: string;
  playerBId: string;
  playerAName: string;
  playerBName: string;
  winnerId: string;
  score: string;
  clubId: string;
  playedAt: string;
  format: MatchFormat;
  division: Division;
};

// ---------------------------------------------------------------------------
// Sala del partido — resultado, validación y reseñas
// ---------------------------------------------------------------------------

export type TeamSide = "A" | "B";

export type SetScore = { a: number; b: number };

export type MatchTeam = {
  side: TeamSide;
  playerIds: string[];
  playerNames: string[];
  /** El capitán registra el resultado por su equipo. */
  captainId: string;
};

export type MatchResult = {
  winner: TeamSide;
  sets: SetScore[];
  reportedById: string;
  reportedByName: string;
  reportedAt: string;
};

/** Reseña dirigida: una por autor y destinatario en cada partido validado. */
export type MatchReview = {
  id?: string;
  matchId?: string;
  authorId: string;
  authorName: string;
  targetId: string;
  targetName: string;
  /** 1-5 estrellas: ¿te gustó el partido? */
  stars: number;
  /** Valoración técnica de esta persona, cada eje de 1 a 10. */
  skillRatings?: PlayerSkills;
  createdAt: string;
};

export type MatchRoomStatus =
  /** Jugado, el capitán aún no registra el marcador. */
  | "awaiting_result"
  /** Resultado registrado, falta que alguien del equipo rival lo confirme. */
  | "awaiting_validation"
  /** Confirmado por el rival — cuenta para el ranking. */
  | "validated"
  /** El rival no está de acuerdo; el capitán debe corregirlo. */
  | "disputed";

export type MatchRoom = {
  id: string;
  format: MatchFormat;
  division: Division;
  clubId: string;
  playedAt: string;
  teamA: MatchTeam;
  teamB: MatchTeam;
  status: MatchRoomStatus;
  result?: MatchResult;
  validation?: { playerId: string; playerName: string; validatedAt: string };
  reviews: MatchReview[];
};

export type Gender = "female" | "male" | "other";
export type AccountRole = "player" | "coach" | "both";

export type AvailabilitySlot = {
  day: string;
  ranges: string[];
};

export type Club = {
  id: string;
  name: string;
  city: string;
  country: string;
  address?: string;
  latitude: number;
  longitude: number;
  courts: number;
};

/** Habilidades tenísticas de 1 a 10, puntuadas por rivales tras partidos validados. */
export type PlayerSkills = {
  consistency: number;
  volley: number;
  forehand: number;
  backhand: number;
  serve: number;
};

/**
 * Perfil deportivo del usuario. Se almacena en Firestore en `players/{uid}`.
 * El `id` coincide con el UID de Firebase Auth.
 */
export type Player = {
  id: string;
  name: string;
  age: number;
  gender: Gender;
  /** Experiencia principal: competir, entrenar o ambas. */
  accountRole?: AccountRole;
  /** Clubes habituales del jugador (muchos son miembros de varios clubes). */
  clubIds: string[];
  city: string;
  country: string;
  /** Coordenadas derivadas del primer club habitual. Ya no se usan para matching. */
  latitude: number;
  longitude: number;
  level: SkillLevel;
  preferredFormats: MatchFormat[];
  availability: AvailabilitySlot[];
  bio: string;
  rating: number;
  responseRate: number;
  languages: string[];
  photoURL?: string | null;
  /** Identidad confirmada mediante un proveedor autenticado (Google/Apple). */
  verified?: boolean;
  /** Indica si el usuario completó el onboarding (nombre, nivel, etc.). */
  profileComplete?: boolean;
  /** Media técnica 1-10 recibida de rivales; si falta, se calcula desde reseñas. */
  skills?: PlayerSkills;
  /** Publica al jugador en el buscador de compañeros de dobles/mixto. */
  seekingTeam?: boolean;
  /** Centro en el que desea formar el equipo; normalmente coincide con clubIds[0]. */
  seekingTeamClubId?: string;
  /** IDs de ligas públicas (una por rango) a las que el jugador se ha inscrito. */
  publicLeagues?: string[];
  /** Perfil local de muestra: puede rellenar listados, pero nunca admite acciones. */
  isDemo?: boolean;
};

export type MatchCandidate = {
  player: Player;
  score: number;
  sharedSlots: string[];
  reasons: string[];
};

/**
 * Propuesta de partido ABIERTA: no se dirige a una persona concreta.
 * Cualquier jugador compatible puede verla y aceptarla. El creador publica
 * una reserva específica (fecha, horario y cancha) para que el rival la vea.
 */
export type MatchProposal = {
  id: string;
  fromPlayerId: string;
  /** Quien aceptó la propuesta. `null` mientras esté abierta. */
  acceptedByPlayerId: string | null;
  clubId: string;
  proposedAt: string;
  /** Fecha y hora concretas del partido (ISO), derivada de la reserva. */
  startsAt: string;
  /** Horario de la reserva ya hecha, ej. "10:00-12:00". Específica, no rango. */
  reservationTime: string;
  /** Número de cancha reservada (1-6). */
  court: number;
  status: MatchStatus;
  format: MatchFormat;
  division: Division;
  /** Niveles que el organizador acepta para este partido informal. */
  acceptedLevels?: SkillLevel[];
  message: string;
};

export type MatchJoinRequestStatus = "pending" | "accepted" | "declined";

export type MatchJoinRequest = {
  id: string;
  matchId: string;
  ownerId: string;
  requesterId: string;
  requesterName: string;
  requesterLevel: SkillLevel;
  status: MatchJoinRequestStatus;
  createdAt: string;
};

export type SearchPreferences = {
  level: "any" | SkillLevel;
  formats: MatchFormat[];
  ageMin: number;
  ageMax: number;
  requireSharedAvailability: boolean;
};

/**
 * Datos de un usuario autenticado con Firebase Auth.
 * Lo usamos en la capa de presentación a través del hook useAuth().
 */
export type AuthUser = {
  uid: string;
  email: string | null;
  displayName: string | null;
  photoURL: string | null;
  emailVerified: boolean;
  providerId: "google.com" | "apple.com" | "password" | "anonymous";
};

/**
 * Payload para crear o actualizar un perfil de jugador en Firestore.
 * Es el subset de Player editable por el propio usuario en el onboarding.
 */
export type PlayerProfileInput = {
  name: string;
  age: number;
  gender: Gender;
  accountRole: AccountRole;
  clubIds: string[];
  city: string;
  country: string;
  latitude: number;
  longitude: number;
  level: SkillLevel;
  preferredFormats: MatchFormat[];
  availability: AvailabilitySlot[];
  bio: string;
  languages: string[];
  photoURL?: string | null;
  verified?: boolean;
  /** Autoevaluación inicial (1-10) pedida en el onboarding; los rivales la afinan luego. */
  skills?: PlayerSkills;
};

// ---------------------------------------------------------------------------
// Comunidad y monetización
// ---------------------------------------------------------------------------

export type CoachAdPlan = "week" | "month";
export type CoachAdStatus = "draft" | "pending_payment" | "active" | "expired";

/** Tarjeta pública que aparece en el muro de entrenadores. */
export type CoachAd = {
  id: string;
  ownerId: string;
  coachName: string;
  photoURL?: string | null;
  headline: string;
  bio: string;
  city: string;
  clubIds: string[];
  specialties: string[];
  priceNote?: string;
  plan: CoachAdPlan;
  status: CoachAdStatus;
  createdAt: string;
  activeFrom?: string;
  expiresAt?: string;
};

/** El contacto vive en un documento privado y solo se revela tras mostrar interés. */
export type CoachContact = {
  phone?: string;
  whatsapp?: string;
  email?: string;
  website?: string;
};

export type CoachInterest = {
  id: string;
  coachAdId: string;
  coachOwnerId: string;
  interestedUserId: string;
  interestedName: string;
  interestedPhotoURL?: string | null;
  createdAt: string;
  readAt?: string;
};

export type PrivateLeague = {
  id: string;
  ownerId: string;
  name: string;
  description: string;
  division: Division;
  format: "singles" | "doubles";
  maxMembers: number;
  memberIds: string[];
  inviteCode: string;
  createdAt: string;
};

export type PrivateLeagueInput = Pick<
  PrivateLeague,
  "name" | "description" | "division" | "format" | "maxMembers"
>;
