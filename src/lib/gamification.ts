import { MatchRoom, RankTier } from "@/types";

/**
 * Progreso del jugador — puntos, niveles, anillos semanales y medallas.
 *
 * Todo se deriva de partidos ya validados y de las reseñas que viajan dentro de
 * cada sala, así que no hace falta ninguna colección nueva en Firestore ni
 * lecturas adicionales: las pantallas que muestran progreso ya cargan esos
 * datos. Un contador guardado en el servidor sería más barato de leer, pero
 * también sería falsificable desde el cliente mientras no exista backend de
 * escritura; derivarlo de resultados validados por el rival lo hace honesto.
 *
 * El módulo es puro a propósito (sin React, sin Firebase) para poder probarlo.
 */

// ---------------------------------------------------------------------------
// Puntuación
// ---------------------------------------------------------------------------

/** Cuánto suma cada cosa. Jugar siempre puntúa; ganar solo añade. */
export const XP_RULES = {
  /** Disputar un partido y que el rival confirme el resultado. */
  playedMatch: 50,
  /** Ganarlo. */
  win: 30,
  /** Cada set ganado, se gane o se pierda el partido. */
  setWon: 10,
  /** Primera vez que juegas contra alguien: la app quiere que amplíes círculo. */
  newRival: 25,
  /** Los dobles mueven a cuatro personas; se premian un poco más. */
  doubles: 10,
  /** Puntuar al rival cierra el ciclo del partido. */
  reviewGiven: 15
} as const;

/**
 * Coste del salto de nivel: 100 para el 2, y 50 más por cada nivel siguiente.
 * Un partido ganado a dos sets ronda los 100 puntos, así que el primer nivel
 * cae el mismo día del debut y el 10 pide unos 27 partidos.
 */
export function xpForLevel(level: number): number {
  if (level <= 1) return 0;
  const steps = level - 1;
  return steps * 100 + 50 * ((steps * (steps - 1)) / 2);
}

export const MAX_LEVEL = 30;

/** Rango visible, reutiliza los colores de tier que ya usa el ranking. */
export function tierForLevel(level: number): RankTier {
  if (level >= 20) return "elite";
  if (level >= 15) return "platino";
  if (level >= 10) return "oro";
  if (level >= 5) return "plata";
  return "bronce";
}

export type LevelProgress = {
  level: number;
  tier: RankTier;
  xp: number;
  /** Puntos ya conseguidos dentro del nivel actual. */
  xpIntoLevel: number;
  /** Puntos que cuesta el nivel actual completo. */
  xpForNextLevel: number;
  /** 0..1 — listo para pintar una barra. */
  progress: number;
  maxed: boolean;
};

export function levelFromXp(xp: number): LevelProgress {
  const safeXp = Math.max(0, Math.floor(xp));
  let level = 1;
  while (level < MAX_LEVEL && safeXp >= xpForLevel(level + 1)) level += 1;
  const floor = xpForLevel(level);
  const ceiling = xpForLevel(level + 1);
  const maxed = level >= MAX_LEVEL;
  const span = ceiling - floor;
  return {
    level,
    tier: tierForLevel(level),
    xp: safeXp,
    xpIntoLevel: safeXp - floor,
    xpForNextLevel: maxed ? 0 : span,
    progress: maxed ? 1 : Math.min(1, (safeXp - floor) / span),
    maxed
  };
}

// ---------------------------------------------------------------------------
// Semanas
// ---------------------------------------------------------------------------

const DAY_MS = 24 * 60 * 60 * 1000;

/** Lunes 00:00 de la semana local que contiene `date`. */
export function startOfWeek(date: Date): Date {
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  // getDay(): 0 = domingo. Queremos que la semana empiece el lunes.
  const offset = (start.getDay() + 6) % 7;
  start.setDate(start.getDate() - offset);
  return start;
}

function weekIndex(date: Date, reference: Date): number {
  const diff = startOfWeek(reference).getTime() - startOfWeek(date).getTime();
  return Math.round(diff / (7 * DAY_MS));
}

// ---------------------------------------------------------------------------
// Anillos semanales
// ---------------------------------------------------------------------------

export type RingKey = "play" | "compete" | "connect";

export type WeeklyGoals = Record<RingKey, number>;

/**
 * Tres objetivos que se reinician cada lunes, al estilo de los anillos de
 * actividad. Ninguno depende de ganar: se cierran jugando, disputando sets y
 * relacionándote, para que una mala racha de resultados no apague el progreso.
 *
 * Son solo el punto de partida: cada persona ajusta los suyos desde la pantalla
 * de progreso. Un objetivo que no encaja con la vida de quien juega una vez al
 * mes no motiva, desanima.
 */
export const DEFAULT_WEEKLY_GOALS: WeeklyGoals = {
  /** Partidos validados en la semana. */
  play: 2,
  /** Sets disputados en la semana. */
  compete: 6,
  /** Rivales distintos + reseñas escritas en la semana. */
  connect: 3
};

/** Márgenes de ajuste. El mínimo es 1 para que el anillo siga significando algo. */
export const WEEKLY_GOAL_LIMITS: Record<RingKey, { min: number; max: number; step: number }> = {
  play: { min: 1, max: 14, step: 1 },
  compete: { min: 2, max: 40, step: 2 },
  connect: { min: 1, max: 20, step: 1 }
};

/** Recorta unos objetivos a sus límites; protege de datos guardados corruptos. */
export function normalizeWeeklyGoals(input: Partial<WeeklyGoals> | null | undefined): WeeklyGoals {
  const result = { ...DEFAULT_WEEKLY_GOALS };
  for (const key of Object.keys(DEFAULT_WEEKLY_GOALS) as RingKey[]) {
    const value = input?.[key];
    if (typeof value !== "number" || !Number.isFinite(value)) continue;
    const { min, max } = WEEKLY_GOAL_LIMITS[key];
    result[key] = Math.min(max, Math.max(min, Math.round(value)));
  }
  return result;
}

export type Ring = {
  key: RingKey;
  value: number;
  goal: number;
  /** 0..1, recortado: el anillo se llena, no se desborda. */
  progress: number;
  closed: boolean;
};

export type WeeklyRings = {
  rings: Ring[];
  /** Los tres cerrados: la semana perfecta. */
  allClosed: boolean;
  weekStart: string;
};

// ---------------------------------------------------------------------------
// Medallas
// ---------------------------------------------------------------------------

export type MedalTier = "bronce" | "plata" | "oro";
export const MEDAL_TIERS: MedalTier[] = ["bronce", "plata", "oro"];

export type MedalMetric =
  | "matches"
  | "wins"
  | "bestWinStreak"
  | "weekStreak"
  | "rivals"
  | "setsWon"
  | "doubles"
  | "clubs"
  | "comebacks"
  | "reviewsGiven"
  | "perfectWeeks"
  | "earlyOrLate";

export type MedalDefinition = {
  id: string;
  metric: MedalMetric;
  icon: string;
  /** Umbrales de bronce, plata y oro. */
  thresholds: [number, number, number];
};

/**
 * Catálogo de medallas. Mezcla deliberada de volumen, resultado, constancia y
 * comunidad: quien no gana casi nunca todavía puede llenar la vitrina.
 */
export const MEDALS: MedalDefinition[] = [
  { id: "debut", metric: "matches", icon: "tennis", thresholds: [1, 10, 50] },
  { id: "victories", metric: "wins", icon: "trophy", thresholds: [1, 10, 25] },
  { id: "streak", metric: "bestWinStreak", icon: "zap", thresholds: [3, 5, 10] },
  { id: "regular", metric: "weekStreak", icon: "calendar", thresholds: [2, 6, 12] },
  { id: "social", metric: "rivals", icon: "users", thresholds: [3, 10, 25] },
  { id: "sets", metric: "setsWon", icon: "check", thresholds: [10, 50, 150] },
  { id: "doubles", metric: "doubles", icon: "user", thresholds: [1, 5, 20] },
  { id: "explorer", metric: "clubs", icon: "building", thresholds: [2, 4, 8] },
  { id: "comeback", metric: "comebacks", icon: "star", thresholds: [1, 3, 10] },
  { id: "fairplay", metric: "reviewsGiven", icon: "check-badge", thresholds: [1, 10, 30] },
  { id: "perfectWeek", metric: "perfectWeeks", icon: "calendar-plus", thresholds: [1, 4, 12] },
  { id: "clock", metric: "earlyOrLate", icon: "clock", thresholds: [1, 5, 15] }
];

export type MedalProgress = {
  id: string;
  icon: string;
  metric: MedalMetric;
  value: number;
  /** Nivel conseguido, o null si todavía no llega ni al bronce. */
  tier: MedalTier | null;
  /** Umbral que falta por alcanzar, o null si ya es de oro. */
  nextThreshold: number | null;
  /** 0..1 hacia el siguiente umbral (1 cuando ya es de oro). */
  progress: number;
  unlocked: boolean;
};

function medalProgress(definition: MedalDefinition, value: number): MedalProgress {
  const [bronze, silver, gold] = definition.thresholds;
  const tier: MedalTier | null =
    value >= gold ? "oro" : value >= silver ? "plata" : value >= bronze ? "bronce" : null;
  const nextThreshold = value >= gold ? null : value >= silver ? gold : value >= bronze ? silver : bronze;
  const previous = value >= silver ? silver : value >= bronze ? bronze : 0;
  return {
    id: definition.id,
    icon: definition.icon,
    metric: definition.metric,
    value,
    tier,
    nextThreshold,
    progress: nextThreshold === null ? 1 : Math.min(1, (value - previous) / (nextThreshold - previous)),
    unlocked: tier !== null
  };
}

// ---------------------------------------------------------------------------
// Cálculo
// ---------------------------------------------------------------------------

export type PlayerStats = {
  matches: number;
  wins: number;
  losses: number;
  winRate: number | null;
  setsWon: number;
  setsPlayed: number;
  currentWinStreak: number;
  bestWinStreak: number;
  rivals: number;
  clubs: number;
  doubles: number;
  comebacks: number;
  reviewsGiven: number;
  weekStreak: number;
  perfectWeeks: number;
  earlyOrLate: number;
};

export type GamificationSummary = {
  stats: PlayerStats;
  level: LevelProgress;
  week: WeeklyRings;
  medals: MedalProgress[];
  /** Últimos resultados, del más antiguo al más reciente. */
  form: Array<"W" | "L">;
};

type RoomView = {
  playedAt: Date;
  won: boolean;
  setsWon: number;
  setsPlayed: number;
  lostFirstSet: boolean;
  rivalIds: string[];
  clubId: string;
  doubles: boolean;
  reviewsGiven: number;
};

function toRoomView(room: MatchRoom, playerId: string): RoomView | null {
  if (room.status !== "validated" || !room.result) return null;
  const inTeamA = room.teamA.playerIds.includes(playerId);
  const inTeamB = room.teamB.playerIds.includes(playerId);
  if (!inTeamA && !inTeamB) return null;

  const side = inTeamA ? "A" : "B";
  const rivals = inTeamA ? room.teamB.playerIds : room.teamA.playerIds;
  const sets = room.result.sets ?? [];
  const mine = (set: { a: number; b: number }) => (side === "A" ? set.a : set.b);
  const theirs = (set: { a: number; b: number }) => (side === "A" ? set.b : set.a);
  const firstSet = sets[0];

  const playedAt = new Date(room.playedAt);
  if (Number.isNaN(playedAt.getTime())) return null;

  return {
    playedAt,
    won: room.result.winner === side,
    setsWon: sets.filter((set) => mine(set) > theirs(set)).length,
    setsPlayed: sets.length,
    lostFirstSet: firstSet ? mine(firstSet) < theirs(firstSet) : false,
    rivalIds: rivals.filter((id) => id !== playerId),
    clubId: room.clubId,
    doubles: room.format !== "singles",
    // Una reseña por rival puntuado; el rival puede dejar la suya sin que cuente aquí.
    reviewsGiven: room.reviews.filter((review) => review.authorId === playerId).length
  };
}

export function summarizeProgress(
  rooms: MatchRoom[],
  playerId: string,
  now: Date = new Date(),
  goals: WeeklyGoals = DEFAULT_WEEKLY_GOALS
): GamificationSummary {
  const weeklyGoals = normalizeWeeklyGoals(goals);
  const views = rooms
    .map((room) => toRoomView(room, playerId))
    .filter((view): view is RoomView => view !== null)
    // Cronológico: las rachas y los "rivales nuevos" dependen del orden real.
    .sort((a, b) => a.playedAt.getTime() - b.playedAt.getTime());

  const seenRivals = new Set<string>();
  const clubs = new Set<string>();
  const weeksPlayed = new Map<number, { matches: number; sets: number; rivals: Set<string>; reviews: number }>();

  let xp = 0;
  let wins = 0;
  let setsWon = 0;
  let setsPlayed = 0;
  let currentWinStreak = 0;
  let bestWinStreak = 0;
  let doubles = 0;
  let comebacks = 0;
  let reviewsGiven = 0;
  let earlyOrLate = 0;

  for (const view of views) {
    xp += XP_RULES.playedMatch + view.setsWon * XP_RULES.setWon;
    if (view.won) {
      xp += XP_RULES.win;
      wins += 1;
      currentWinStreak += 1;
      bestWinStreak = Math.max(bestWinStreak, currentWinStreak);
      if (view.lostFirstSet) comebacks += 1;
    } else {
      currentWinStreak = 0;
    }

    for (const rivalId of view.rivalIds) {
      if (!seenRivals.has(rivalId)) {
        seenRivals.add(rivalId);
        xp += XP_RULES.newRival;
      }
    }

    if (view.doubles) {
      doubles += 1;
      xp += XP_RULES.doubles;
    }

    xp += view.reviewsGiven * XP_RULES.reviewGiven;
    reviewsGiven += view.reviewsGiven;
    setsWon += view.setsWon;
    setsPlayed += view.setsPlayed;
    clubs.add(view.clubId);

    const hour = view.playedAt.getHours();
    if (hour < 9 || hour >= 21) earlyOrLate += 1;

    const index = weekIndex(view.playedAt, now);
    if (index >= 0) {
      const week = weeksPlayed.get(index) ?? { matches: 0, sets: 0, rivals: new Set<string>(), reviews: 0 };
      week.matches += 1;
      week.sets += view.setsPlayed;
      week.reviews += view.reviewsGiven;
      for (const rivalId of view.rivalIds) week.rivals.add(rivalId);
      weeksPlayed.set(index, week);
    }
  }

  // Racha de constancia: semanas seguidas con al menos un partido. La semana en
  // curso todavía se puede salvar, así que no rompe la racha si está vacía.
  let weekStreak = 0;
  for (let index = weeksPlayed.has(0) ? 0 : 1; weeksPlayed.has(index); index += 1) weekStreak += 1;

  // Las semanas perfectas se miden contra los objetivos ACTUALES. Si alguien
  // los baja, semanas antiguas pueden pasar a contar: preferimos eso a guardar
  // un histórico de objetivos que nadie va a poder interpretar después.
  const perfectWeeks = [...weeksPlayed.values()].filter(
    (week) =>
      week.matches >= weeklyGoals.play &&
      week.sets >= weeklyGoals.compete &&
      week.rivals.size + week.reviews >= weeklyGoals.connect
  ).length;

  const current = weeksPlayed.get(0);
  const ringValues: Record<RingKey, number> = {
    play: current?.matches ?? 0,
    compete: current?.sets ?? 0,
    connect: current ? current.rivals.size + current.reviews : 0
  };
  const rings: Ring[] = (Object.keys(weeklyGoals) as RingKey[]).map((key) => {
    const goal = weeklyGoals[key];
    const value = ringValues[key];
    return { key, value, goal, progress: Math.min(1, value / goal), closed: value >= goal };
  });

  const stats: PlayerStats = {
    matches: views.length,
    wins,
    losses: views.length - wins,
    winRate: views.length === 0 ? null : Math.round((wins / views.length) * 100),
    setsWon,
    setsPlayed,
    currentWinStreak,
    bestWinStreak,
    rivals: seenRivals.size,
    clubs: clubs.size,
    doubles,
    comebacks,
    reviewsGiven,
    weekStreak,
    perfectWeeks,
    earlyOrLate
  };

  const metricValues: Record<MedalMetric, number> = {
    matches: stats.matches,
    wins: stats.wins,
    bestWinStreak: stats.bestWinStreak,
    weekStreak: stats.weekStreak,
    rivals: stats.rivals,
    setsWon: stats.setsWon,
    doubles: stats.doubles,
    clubs: stats.clubs,
    comebacks: stats.comebacks,
    reviewsGiven: stats.reviewsGiven,
    perfectWeeks: stats.perfectWeeks,
    earlyOrLate: stats.earlyOrLate
  };

  return {
    stats,
    level: levelFromXp(xp),
    week: {
      rings,
      allClosed: rings.every((ring) => ring.closed),
      weekStart: startOfWeek(now).toISOString()
    },
    medals: MEDALS.map((definition) => medalProgress(definition, metricValues[definition.metric])),
    form: views.slice(-6).map((view) => (view.won ? "W" : "L"))
  };
}

/**
 * Qué le falta al jugador para el siguiente hito. Se usa como empujón en la
 * pantalla de progreso: un objetivo concreto rinde más que doce a la vez.
 */
export function nextMilestone(summary: GamificationSummary): { id: string; remaining: number } | null {
  const pending = summary.medals
    .filter((medal) => medal.nextThreshold !== null)
    .map((medal) => ({ id: medal.id, remaining: medal.nextThreshold! - medal.value }))
    .sort((a, b) => a.remaining - b.remaining);
  return pending[0] ?? null;
}
