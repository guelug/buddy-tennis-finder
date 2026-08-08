import LocalAI, { type LocalAIAvailability } from "@/../modules/matchpoint-local-ai/src";
import { tournaments, publicLeagueForDivision, publicLeagueIdsFor } from "@/data/competition-hub";
import { DIVISION_LABELS } from "@/data/rankings";
import { getHomeData } from "@/lib/app-api";
import { detectIdentityIntent, identityAnswerText } from "@/lib/assistant-identity";
import { getMatchRooms, scoreLine } from "@/lib/match-room";
import type { Club, MatchProposal, MatchRoom, Player } from "@/types";

export { detectIdentityIntent, type IdentityIntent } from "@/lib/assistant-identity";

/** Acción que el asistente puede ofrecer al final de una respuesta. */
export type AssistantAction = {
  id: "rivals" | "matches" | "ranking" | "league" | "profile" | "tournaments";
  labelKey: string;
  route: string;
};

export type AssistantResultLine = {
  opponent: string;
  score: string;
  won: boolean | null;
  playedAt: string;
  clubName?: string;
  validated: boolean;
};

export type AssistantContext = {
  player: Player;
  clubs: Club[];
  /** Rivales sugeridos por el motor de matching, ya ordenados. */
  candidates: Array<{ name: string; level: string; clubName?: string; reasons: string[] }>;
  acceptedMatches: MatchProposal[];
  upcomingMatches: MatchProposal[];
  /** Propuestas abiertas del jugador que todavía nadie ha aceptado. */
  openProposals: MatchProposal[];
  pendingJoinRequests: number;
  /** Resultados con marcador; solo los validados cuentan para el ranking. */
  recentResults: AssistantResultLine[];
  openTournaments: typeof tournaments;
  publicLeague: ReturnType<typeof publicLeagueForDivision>;
  leagueJoined: boolean;
  /** Posición dentro del ranking provisional de su división. */
  ranking: { rank: number; total: number } | null;
  wins: number;
  losses: number;
};

function describeRoom(room: MatchRoom, playerId: string, clubs: Club[]): AssistantResultLine {
  const mine = room.teamA.playerIds.includes(playerId) ? "A" : "B";
  const rivalTeam = mine === "A" ? room.teamB : room.teamA;
  const score = scoreLine(room) ?? "";
  return {
    opponent: rivalTeam.playerNames.join(" / "),
    score,
    won: room.result ? room.result.winner === mine : null,
    playedAt: room.playedAt,
    clubName: clubs.find((club) => club.id === room.clubId)?.name,
    validated: room.status === "validated"
  };
}

export async function getAssistantContext(uid?: string): Promise<AssistantContext> {
  // Las dos cargas son independientes cuando ya conocemos el uid, y antes
  // iban en serie: primero las ~6 consultas de getHomeData y después las de
  // getMatchRooms. Lanzándolas a la vez, abrir el asistente cuesta lo que
  // tarde la más lenta en vez de la suma de ambas.
  const [home, roomsIfKnown] = await Promise.all([
    getHomeData(undefined, uid),
    uid ? getMatchRooms(uid).catch(() => [] as MatchRoom[]) : Promise.resolve(null)
  ]);
  const player = home.currentPlayer;
  const playerId = uid ?? player.id;
  const rooms = roomsIfKnown ?? await getMatchRooms(playerId).catch(() => [] as MatchRoom[]);

  const acceptedMatches = home.proposals.filter((match) => match.status === "accepted");
  const upcomingMatches = acceptedMatches
    .filter((match) => new Date(match.startsAt).getTime() > Date.now())
    .sort((a, b) => a.startsAt.localeCompare(b.startsAt));

  const recentResults = rooms
    .filter((room) => Boolean(room.result))
    .slice(0, 5)
    .map((room) => describeRoom(room, playerId, home.clubs));

  // Solo los partidos validados por el rival cuentan como victoria o derrota.
  const validated = recentResults.filter((line) => line.validated);

  // Ranking provisional: mismo criterio que la pestaña Ranking (perfiles
  // reales y completos de la división, ordenados por nombre) para no dar
  // al jugador una posición distinta de la que ve en pantalla.
  const divisionPeers = home.players
    .filter((item) => item.profileComplete && item.level === player.level && item.isDemo !== true)
    .sort((a, b) => a.name.localeCompare(b.name));
  const rankIndex = divisionPeers.findIndex((item) => item.id === playerId);

  return {
    player,
    clubs: home.clubs,
    candidates: home.candidates.slice(0, 5).map((candidate) => ({
      name: candidate.player.name,
      level: candidate.player.level,
      clubName: home.clubs.find((club) => candidate.player.clubIds.includes(club.id))?.name,
      reasons: candidate.reasons
    })),
    acceptedMatches,
    upcomingMatches,
    openProposals: home.proposals.filter((match) => match.status === "proposed" && match.fromPlayerId === playerId),
    pendingJoinRequests: home.joinRequests.filter((request) => request.status === "pending").length,
    recentResults,
    openTournaments: tournaments.filter((item) => item.status === "registration" && item.division === player.level),
    publicLeague: publicLeagueForDivision(player.level, player.city),
    leagueJoined: Boolean(player.publicLeagues?.some((id) => publicLeagueIdsFor(player.level, player.city).includes(id))),
    ranking: rankIndex >= 0 ? { rank: rankIndex + 1, total: divisionPeers.length } : null,
    // Nunca inferimos victorias de perfiles o datos de demostración: solo
    // cuentan los resultados que el rival ha confirmado.
    wins: validated.filter((line) => line.won === true).length,
    losses: validated.filter((line) => line.won === false).length
  };
}

/**
 * La disponibilidad del modelo no cambia mientras la app está abierta, pero
 * consultarla cruza el puente nativo y en iOS despierta la sesión de Apple
 * Intelligence, que es lenta la primera vez. Se pedía en cada apertura del
 * asistente y además en cada pregunta; ahora se resuelve una sola vez y se
 * reutiliza la misma promesa.
 */
let availabilityCache: Promise<LocalAIAvailability> | null = null;

export function getLocalAIAvailability(): Promise<LocalAIAvailability> {
  if (availabilityCache) return availabilityCache;
  availabilityCache = (async () => {
    if (!LocalAI) return { available: false, provider: "fallback", reason: "Modelo local no incluido en esta plataforma" } as LocalAIAvailability;
    try {
      return await LocalAI.getAvailability();
    } catch {
      return { available: false, provider: "fallback", reason: "Modelo local no disponible" } as LocalAIAvailability;
    }
  })();
  return availabilityCache;
}

/**
 * Contexto que se envía al modelo local. Va como JSON explícito y etiquetado
 * para que el modelo no tenga que adivinar qué es real: todo lo que no esté
 * aquí, no existe.
 */
function groundedPrompt(question: string, context: AssistantContext, languageName: string, assistantName: string) {
  const payload = {
    jugador: {
      nombre: context.player.name,
      nivel: DIVISION_LABELS[context.player.level],
      ciudad: context.player.city,
      clubes: context.player.clubIds
        .map((id) => context.clubs.find((club) => club.id === id)?.name)
        .filter(Boolean),
      formatos: context.player.preferredFormats,
      disponibilidad: context.player.availability,
      autoevaluacion: context.player.skills ?? null
    },
    ranking: context.ranking
      ? { posicion: context.ranking.rank, jugadoresEnDivision: context.ranking.total, puntos: 0, nota: "Ranking provisional: los puntos arrancan cuando se valide el primer resultado." }
      : { nota: "El jugador todavía no aparece en el ranking de su división." },
    estadisticas_validadas: {
      partidosAceptados: context.acceptedMatches.length,
      victorias: context.wins,
      derrotas: context.losses
    },
    ultimos_resultados: context.recentResults.map((line) => ({
      rival: line.opponent,
      marcador: line.score,
      resultado: line.won === null ? "sin marcador" : line.won ? "victoria" : "derrota",
      fecha: line.playedAt,
      club: line.clubName ?? null,
      validadoPorElRival: line.validated
    })),
    proximos_partidos: context.upcomingMatches.map((match) => ({
      fecha: match.startsAt,
      club: context.clubs.find((club) => club.id === match.clubId)?.name ?? match.clubId,
      pista: match.court,
      horario: match.reservationTime,
      formato: match.format
    })),
    propuestas_abiertas: context.openProposals.length,
    solicitudes_pendientes: context.pendingJoinRequests,
    rivales_sugeridos: context.candidates.map((candidate) => ({
      nombre: candidate.name,
      nivel: DIVISION_LABELS[candidate.level as keyof typeof DIVISION_LABELS] ?? candidate.level,
      club: candidate.clubName ?? null,
      porQue: candidate.reasons
    })),
    torneos_con_inscripcion: context.openTournaments.map((item) => ({
      nombre: item.name,
      division: item.division,
      plazasReales: item.entrants,
      capacidad: item.capacity,
      nota: "Vista previa; confirmar publicación antes de prometer inscripción"
    })),
    liga_publica: {
      nombre: context.publicLeague.name,
      estado: context.publicLeague.status,
      inscrito: context.leagueJoined,
      inscritosReales: context.publicLeague.participants,
      capacidad: context.publicLeague.capacity
    }
  };
  return [
    `Eres ${assistantName}, el asistente personal de MatchPoint, dentro de una app de tenis. Responde en ${languageName}.`,
    "Identidades separadas, no las confundas nunca:",
    `- Tú eres ${assistantName}, el asistente. Si el jugador te pregunta quién eres o cómo te llamas, preséntate como ${assistantName}, su asistente.`,
    `- El jugador que te escribe se llama ${context.player.name}. Si te pregunta si sabes quién es, responde que es ${context.player.name}. Nunca digas que tú eres ${context.player.name}: ese nombre es del jugador, no tuyo.`,
    "Usa exclusivamente los datos verificados de abajo. Si un dato no aparece, di que todavía no está registrado; nunca lo inventes ni lo estimes.",
    "Responde en 3 frases como máximo, en tono directo y práctico.",
    "",
    `Pregunta del jugador (${context.player.name}): ${question}`,
    "",
    `Datos verificados del jugador en MatchPoint (JSON):\n${JSON.stringify(payload)}`
  ].join("\n");
}

export type AssistantAnswer = {
  text: string;
  provider: string;
  actions: AssistantAction[];
};

export type Translate = (key: string) => string;

export async function askMatchPointAssistant(
  question: string,
  context: AssistantContext,
  t: Translate,
  languageName = "español",
  assistantName = "Match Buddy"
): Promise<AssistantAnswer> {
  const identity = detectIdentityIntent(question);
  if (identity) {
    const profile: AssistantAction = { id: "profile", labelKey: "assistant.action.profile", route: "/profile" };
    const ranking: AssistantAction = { id: "ranking", labelKey: "assistant.action.ranking", route: "/liga" };
    const rivals: AssistantAction = { id: "rivals", labelKey: "assistant.action.rivals", route: "/" };
    const actions = identity === "user" ? [profile, ranking] : [rivals, ranking];
    return {
      text: identityAnswerText(identity, {
        assistantName,
        playerName: context.player.name,
        divisionLabel: DIVISION_LABELS[context.player.level],
        city: context.player.city
      }, t),
      provider: "fallback",
      actions
    };
  }
  const intent = detectIntent(question);
  const actions = actionsForIntent(intent, context);
  const availability = await getLocalAIAvailability();
  if (availability.available && LocalAI) {
    try {
      const generated = await LocalAI.generate(groundedPrompt(question, context, languageName, assistantName));
      const text = cleanAssistantText(generated);
      if (text) return { text, provider: availability.provider, actions };
    } catch {
      // El modelo puede quedar temporalmente sin cuota o memoria. La respuesta
      // determinista mantiene el asistente útil y nunca envía datos a la nube.
    }
  }
  return { text: fallbackAnswer(intent, context, t), provider: "fallback", actions };
}

export function cleanAssistantText(value: string) {
  const withoutFence = value
    .trim()
    .replace(/^```(?:json|markdown|text)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  if (!withoutFence.startsWith("{") && !withoutFence.startsWith("[")) {
    return withoutFence;
  }

  try {
    const parsed = JSON.parse(withoutFence);
    if (typeof parsed === "string") return parsed.trim();
    for (const key of ["answer", "respuesta", "text", "content", "message"]) {
      if (typeof parsed?.[key] === "string") return parsed[key].trim();
    }
  } catch {
    // La salida visible nunca debe conservar una valla Markdown aunque el
    // modelo haya producido un JSON incompleto.
  }
  return withoutFence.replace(/^\{\s*|\s*\}$/g, "").replace(/^"?(answer|respuesta|text|content|message)"?\s*:\s*/i, "").replace(/^"|"$/g, "").trim();
}

// ---------------------------------------------------------------------------
// Intenciones y acciones
// ---------------------------------------------------------------------------

export type AssistantIntent =
  | "results"
  | "ranking"
  | "search"
  | "tournaments"
  | "league"
  | "upcoming"
  | "stats"
  | "improve"
  | "help";

/**
 * Detección de intención por palabras clave en los idiomas que más se usan en
 * la app. No pretende ser un clasificador: decide qué acciones se ofrecen y,
 * si el modelo local no está disponible, qué respuesta determinista damos.
 */
const INTENT_KEYWORDS: Array<{ intent: AssistantIntent; words: string[] }> = [
  { intent: "results", words: ["resultado", "marcador", "puntuacion", "puntuación", "score", "result", "ultimos partidos", "últimos partidos", "last match", "recent match", "gane", "gané", "perdi", "perdí"] },
  { intent: "ranking", words: ["ranking", "clasificacion", "clasificación", "posicion", "posición", "puesto", "standing", "rank"] },
  { intent: "search", words: ["buscar", "busca", "rival", "oponente", "contrincante", "search", "find", "opponent", "jugar con", "compañero", "companero"] },
  { intent: "tournaments", words: ["torneo", "tournament", "cuadro", "bracket"] },
  { intent: "league", words: ["liga", "league"] },
  { intent: "upcoming", words: ["proximo", "próximo", "proxima", "próxima", "manana", "mañana", "agenda", "calendario", "upcoming", "next match", "schedule"] },
  { intent: "stats", words: ["estadistica", "estadística", "balance", "record", "stats", "victorias", "derrotas"] },
  { intent: "improve", words: ["mejorar", "mejora", "consejo", "entrenar", "entrenamiento", "improve", "advice", "train", "practice"] }
];

export function detectIntent(question: string): AssistantIntent {
  const strip = (value: string) => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  const normalized = strip(question.toLocaleLowerCase("es"));
  for (const { intent, words } of INTENT_KEYWORDS) {
    if (words.some((word) => normalized.includes(strip(word)))) {
      return intent;
    }
  }
  return "help";
}

function actionsForIntent(intent: AssistantIntent, context: AssistantContext): AssistantAction[] {
  const league: AssistantAction = { id: "league", labelKey: "assistant.action.league", route: `/league/${context.publicLeague.id}` };
  const rivals: AssistantAction = { id: "rivals", labelKey: "assistant.action.rivals", route: "/" };
  const matches: AssistantAction = { id: "matches", labelKey: "assistant.action.matches", route: "/matches" };
  const ranking: AssistantAction = { id: "ranking", labelKey: "assistant.action.ranking", route: "/liga" };
  const profile: AssistantAction = { id: "profile", labelKey: "assistant.action.profile", route: "/profile" };

  switch (intent) {
    case "results":
      return [matches, ranking];
    case "ranking":
      return [ranking, context.leagueJoined ? league : rivals];
    case "search":
      return [rivals, matches];
    case "tournaments":
      return [ranking];
    case "league":
      return context.leagueJoined ? [league, rivals] : [ranking, rivals];
    case "upcoming":
      return [matches, rivals];
    case "stats":
      return [matches, ranking];
    case "improve":
      return [profile, rivals];
    default:
      return [rivals, matches, ranking];
  }
}

// ---------------------------------------------------------------------------
// Respuestas deterministas (sin modelo local disponible)
// ---------------------------------------------------------------------------

function formatDate(value: string) {
  const date = new Date(value);
  return Number.isFinite(date.getTime()) ? date.toLocaleString() : value;
}

function fallbackAnswer(intent: AssistantIntent, context: AssistantContext, t: Translate): string {
  const fill = (key: string, values: Record<string, string | number>) =>
    Object.entries(values).reduce((text, [token, value]) => text.replaceAll(`{${token}}`, String(value)), t(key));

  switch (intent) {
    case "results": {
      const [last] = context.recentResults;
      if (!last) return t("assistant.answer.noResults");
      return fill(last.validated ? "assistant.answer.lastResult" : "assistant.answer.lastResultPending", {
        opponent: last.opponent,
        score: last.score || "—",
        date: formatDate(last.playedAt)
      });
    }
    case "ranking": {
      if (!context.ranking) return t("assistant.answer.noRanking");
      return fill("assistant.answer.ranking", {
        rank: context.ranking.rank,
        total: context.ranking.total,
        division: DIVISION_LABELS[context.player.level]
      });
    }
    case "search": {
      if (!context.candidates.length) return t("assistant.answer.noCandidates");
      return fill("assistant.answer.candidates", {
        count: context.candidates.length,
        names: context.candidates.slice(0, 3).map((candidate) => candidate.name).join(", ")
      });
    }
    case "tournaments": {
      if (!context.openTournaments.length) {
        return fill("assistant.answer.noTournaments", { division: DIVISION_LABELS[context.player.level] });
      }
      return fill("assistant.answer.tournaments", {
        names: context.openTournaments.map((item) => item.name).join(", ")
      });
    }
    case "league":
      return fill(context.leagueJoined ? "assistant.answer.leagueJoined" : "assistant.answer.leagueOpen", {
        league: context.publicLeague.name,
        participants: context.publicLeague.participants,
        capacity: context.publicLeague.capacity
      });
    case "upcoming": {
      const [next] = context.upcomingMatches;
      if (!next) {
        return context.openProposals.length
          ? fill("assistant.answer.openProposals", { count: context.openProposals.length })
          : t("assistant.answer.noUpcoming");
      }
      return fill("assistant.answer.upcoming", {
        date: formatDate(next.startsAt),
        court: next.court,
        club: context.clubs.find((club) => club.id === next.clubId)?.name ?? ""
      });
    }
    case "stats":
      return fill("assistant.answer.stats", {
        wins: context.wins,
        losses: context.losses,
        matches: context.acceptedMatches.length
      });
    case "improve": {
      const skills = context.player.skills;
      if (!skills) return t("assistant.answer.noSkills");
      const weakest = Object.entries(skills).sort((a, b) => a[1] - b[1])[0];
      return fill("assistant.answer.improve", {
        skill: t(`onboarding.skill.${weakest[0]}`),
        value: weakest[1]
      });
    }
    default:
      return t("assistant.answer.help");
  }
}
