import assert from "node:assert/strict";
import test from "node:test";
import {
  levelFromXp,
  nextMilestone,
  normalizeWeeklyGoals,
  startOfWeek,
  summarizeProgress,
  DEFAULT_WEEKLY_GOALS,
  WEEKLY_GOAL_LIMITS,
  XP_RULES,
  xpForLevel
} from "../src/lib/gamification";
import type { MatchFormat, MatchRoom, MatchReview, SetScore } from "../src/types";

const NOW = new Date(2026, 7, 13, 12, 0, 0); // jueves 13 de agosto de 2026, hora local

/** Fecha local a `days` días de NOW, a la hora indicada. */
function daysAgo(days: number, hour = 18): string {
  const date = new Date(NOW);
  date.setDate(date.getDate() - days);
  date.setHours(hour, 0, 0, 0);
  return date.toISOString();
}

function room(options: {
  id?: string;
  playedAt: string;
  winner: "A" | "B";
  sets?: SetScore[];
  rivals?: string[];
  partners?: string[];
  clubId?: string;
  format?: MatchFormat;
  reviews?: MatchReview[];
  status?: MatchRoom["status"];
}): MatchRoom {
  const rivals = options.rivals ?? ["rival-1"];
  const teamAIds = ["me", ...(options.partners ?? [])];
  return {
    id: options.id ?? `room-${options.playedAt}-${rivals.join("-")}`,
    format: options.format ?? "singles",
    division: "c",
    clubId: options.clubId ?? "club-1",
    playedAt: options.playedAt,
    teamA: { side: "A", playerIds: teamAIds, playerNames: teamAIds, captainId: "me" },
    teamB: { side: "B", playerIds: rivals, playerNames: rivals, captainId: rivals[0] },
    status: options.status ?? "validated",
    result: {
      winner: options.winner,
      sets: options.sets ?? [{ a: 6, b: 4 }, { a: 6, b: 3 }],
      reportedById: "me",
      reportedByName: "Yo",
      reportedAt: options.playedAt
    },
    reviews: options.reviews ?? []
  };
}

function review(authorId: string): MatchReview {
  return {
    authorId,
    authorName: authorId,
    targetId: "rival-1",
    targetName: "rival-1",
    stars: 5,
    createdAt: NOW.toISOString()
  };
}

// ---------------------------------------------------------------------------
// Niveles
// ---------------------------------------------------------------------------

test("la curva de niveles empieza en cero y encarece cada salto", () => {
  assert.equal(xpForLevel(1), 0);
  assert.equal(xpForLevel(2), 100);
  assert.equal(xpForLevel(3), 250);
  assert.equal(xpForLevel(4), 450);

  const saltos = [2, 3, 4, 5, 6].map((level) => xpForLevel(level) - xpForLevel(level - 1));
  assert.deepEqual(saltos, [100, 150, 200, 250, 300]);
});

test("el nivel refleja los puntos acumulados y su progreso parcial", () => {
  assert.equal(levelFromXp(0).level, 1);
  assert.equal(levelFromXp(99).level, 1);
  assert.equal(levelFromXp(100).level, 2);
  assert.equal(levelFromXp(249).level, 2);
  assert.equal(levelFromXp(250).level, 3);

  const mitad = levelFromXp(175);
  assert.equal(mitad.level, 2);
  assert.equal(mitad.xpIntoLevel, 75);
  assert.equal(mitad.xpForNextLevel, 150);
  assert.equal(mitad.progress, 0.5);
});

test("el nivel máximo se queda lleno en vez de desbordarse", () => {
  const tope = levelFromXp(10_000_000);
  assert.equal(tope.level, 30);
  assert.equal(tope.maxed, true);
  assert.equal(tope.progress, 1);
  assert.equal(tope.tier, "elite");
});

test("los puntos negativos o corruptos no rompen el nivel", () => {
  assert.equal(levelFromXp(-500).level, 1);
  assert.equal(levelFromXp(-500).progress, 0);
});

// ---------------------------------------------------------------------------
// Puntos por partido
// ---------------------------------------------------------------------------

test("un partido ganado suma juego, victoria, sets y rival nuevo", () => {
  const summary = summarizeProgress([room({ playedAt: daysAgo(1), winner: "A" })], "me", NOW);

  const esperado = XP_RULES.playedMatch + XP_RULES.win + 2 * XP_RULES.setWon + XP_RULES.newRival;
  assert.equal(summary.level.xp, esperado);
  assert.equal(summary.stats.matches, 1);
  assert.equal(summary.stats.wins, 1);
  assert.equal(summary.stats.winRate, 100);
});

test("perder también suma: se puntúa jugar y los sets ganados", () => {
  const summary = summarizeProgress(
    [room({ playedAt: daysAgo(1), winner: "B", sets: [{ a: 6, b: 4 }, { a: 2, b: 6 }, { a: 3, b: 6 }] })],
    "me",
    NOW
  );

  assert.equal(summary.level.xp, XP_RULES.playedMatch + XP_RULES.setWon + XP_RULES.newRival);
  assert.equal(summary.stats.wins, 0);
  assert.equal(summary.stats.setsWon, 1);
  assert.equal(summary.stats.winRate, 0);
});

test("el mismo rival solo puntúa como nuevo la primera vez", () => {
  const summary = summarizeProgress(
    [
      room({ id: "a", playedAt: daysAgo(20), winner: "A" }),
      room({ id: "b", playedAt: daysAgo(10), winner: "A" })
    ],
    "me",
    NOW
  );

  assert.equal(summary.stats.rivals, 1);
  const porPartido = XP_RULES.playedMatch + XP_RULES.win + 2 * XP_RULES.setWon;
  assert.equal(summary.level.xp, porPartido * 2 + XP_RULES.newRival);
});

test("solo cuentan los partidos validados en los que participó el jugador", () => {
  const summary = summarizeProgress(
    [
      room({ id: "pendiente", playedAt: daysAgo(2), winner: "A", status: "awaiting_validation" }),
      room({ id: "disputado", playedAt: daysAgo(3), winner: "A", status: "disputed" }),
      { ...room({ id: "ajeno", playedAt: daysAgo(4), winner: "A" }), teamA: { side: "A", playerIds: ["otro"], playerNames: ["otro"], captainId: "otro" } },
      room({ id: "valido", playedAt: daysAgo(5), winner: "A" })
    ],
    "me",
    NOW
  );

  assert.equal(summary.stats.matches, 1);
});

test("una fecha corrupta descarta el partido en vez de romper el resumen", () => {
  const summary = summarizeProgress([room({ playedAt: "no-es-una-fecha", winner: "A" })], "me", NOW);
  assert.equal(summary.stats.matches, 0);
  assert.equal(summary.level.xp, 0);
});

// ---------------------------------------------------------------------------
// Rachas
// ---------------------------------------------------------------------------

test("la racha de victorias se corta al perder y conserva la mejor marca", () => {
  const summary = summarizeProgress(
    [
      room({ id: "1", playedAt: daysAgo(40), winner: "A" }),
      room({ id: "2", playedAt: daysAgo(35), winner: "A" }),
      room({ id: "3", playedAt: daysAgo(30), winner: "A" }),
      room({ id: "4", playedAt: daysAgo(25), winner: "B" }),
      room({ id: "5", playedAt: daysAgo(20), winner: "A" })
    ],
    "me",
    NOW
  );

  assert.equal(summary.stats.bestWinStreak, 3);
  assert.equal(summary.stats.currentWinStreak, 1);
  assert.deepEqual(summary.form, ["W", "W", "W", "L", "W"]);
});

test("las remontadas solo cuentan si se perdió el primer set y se ganó el partido", () => {
  const summary = summarizeProgress(
    [
      room({ id: "remontada", playedAt: daysAgo(9), winner: "A", sets: [{ a: 3, b: 6 }, { a: 6, b: 4 }, { a: 6, b: 2 }] }),
      room({ id: "comoda", playedAt: daysAgo(8), winner: "A", sets: [{ a: 6, b: 1 }, { a: 6, b: 0 }] }),
      room({ id: "perdida", playedAt: daysAgo(7), winner: "B", sets: [{ a: 4, b: 6 }, { a: 4, b: 6 }] })
    ],
    "me",
    NOW
  );

  assert.equal(summary.stats.comebacks, 1);
});

test("la constancia cuenta semanas seguidas y no se rompe por la semana en curso", () => {
  // Semanas 1, 2 y 3 hacia atrás; la actual todavía está vacía.
  const summary = summarizeProgress(
    [
      room({ id: "s1", playedAt: daysAgo(8), winner: "A" }),
      room({ id: "s2", playedAt: daysAgo(15), winner: "A" }),
      room({ id: "s3", playedAt: daysAgo(22), winner: "A" })
    ],
    "me",
    NOW
  );

  assert.equal(summary.stats.weekStreak, 3);
});

test("un hueco de una semana corta la constancia", () => {
  const summary = summarizeProgress(
    [
      room({ id: "s1", playedAt: daysAgo(8), winner: "A" }),
      room({ id: "s3", playedAt: daysAgo(22), winner: "A" })
    ],
    "me",
    NOW
  );

  assert.equal(summary.stats.weekStreak, 1);
});

// ---------------------------------------------------------------------------
// Anillos semanales
// ---------------------------------------------------------------------------

test("los anillos solo miran la semana en curso", () => {
  const summary = summarizeProgress(
    [
      room({ id: "estaSemana", playedAt: daysAgo(1), winner: "A" }),
      room({ id: "semanaPasada", playedAt: daysAgo(9), winner: "A" })
    ],
    "me",
    NOW
  );

  const play = summary.week.rings.find((ring) => ring.key === "play")!;
  assert.equal(play.value, 1);
  assert.equal(play.goal, DEFAULT_WEEKLY_GOALS.play);
  assert.equal(play.closed, false);
  assert.equal(play.progress, 0.5);
});

test("una semana completa cierra los tres anillos", () => {
  const summary = summarizeProgress(
    [
      room({ id: "a", playedAt: daysAgo(2), winner: "A", rivals: ["rival-1"], reviews: [review("me")], sets: [{ a: 6, b: 4 }, { a: 3, b: 6 }, { a: 6, b: 2 }] }),
      room({ id: "b", playedAt: daysAgo(1), winner: "B", rivals: ["rival-2"], sets: [{ a: 4, b: 6 }, { a: 6, b: 3 }, { a: 2, b: 6 }] })
    ],
    "me",
    NOW
  );

  assert.equal(summary.week.allClosed, true);
  assert.equal(summary.stats.perfectWeeks, 1);
});

test("el anillo no se desborda por encima del objetivo", () => {
  const partidos = Array.from({ length: 8 }, (_, index) =>
    room({ id: `m${index}`, playedAt: daysAgo(1), winner: "A", rivals: [`rival-${index}`] })
  );
  const summary = summarizeProgress(partidos, "me", NOW);

  for (const ring of summary.week.rings) {
    assert.equal(ring.progress, 1);
    assert.equal(ring.closed, true);
  }
});

test("los anillos usan los objetivos que elige el jugador", () => {
  const partidos = [
    room({ id: "a", playedAt: daysAgo(2), winner: "A" }),
    room({ id: "b", playedAt: daysAgo(1), winner: "A", rivals: ["rival-2"] })
  ];

  const porDefecto = summarizeProgress(partidos, "me", NOW);
  assert.equal(porDefecto.week.rings.find((ring) => ring.key === "play")!.closed, true);

  // Alguien que se propone cuatro partidos por semana no cierra con dos.
  const exigente = summarizeProgress(partidos, "me", NOW, { play: 4, compete: 12, connect: 6 });
  const play = exigente.week.rings.find((ring) => ring.key === "play")!;
  assert.equal(play.goal, 4);
  assert.equal(play.value, 2);
  assert.equal(play.closed, false);
  assert.equal(play.progress, 0.5);
  assert.equal(exigente.week.allClosed, false);
});

test("un objetivo más suave cierra el anillo con los mismos partidos", () => {
  const partidos = [room({ playedAt: daysAgo(1), winner: "A" })];
  const suave = summarizeProgress(partidos, "me", NOW, { play: 1, compete: 2, connect: 1 });

  assert.equal(suave.week.allClosed, true);
  assert.equal(suave.stats.perfectWeeks, 1);
});

test("unos objetivos corruptos o fuera de rango se recortan a los límites", () => {
  assert.deepEqual(normalizeWeeklyGoals({ play: 0, compete: 999, connect: 3 }), {
    play: WEEKLY_GOAL_LIMITS.play.min,
    compete: WEEKLY_GOAL_LIMITS.compete.max,
    connect: 3
  });
  assert.deepEqual(normalizeWeeklyGoals(null), DEFAULT_WEEKLY_GOALS);
  assert.deepEqual(normalizeWeeklyGoals({ play: Number.NaN }), DEFAULT_WEEKLY_GOALS);
  // Un decimal guardado por error se redondea en vez de romper el anillo.
  assert.equal(normalizeWeeklyGoals({ play: 3.6 }).play, 4);
});

test("la semana empieza el lunes local", () => {
  const domingo = new Date(2026, 7, 16, 23, 30); // domingo
  const lunes = new Date(2026, 7, 10, 8, 0); // lunes anterior
  assert.equal(startOfWeek(domingo).getTime(), lunes.getTime() - 8 * 60 * 60 * 1000);
  assert.equal(startOfWeek(lunes).getDay(), 1);
});

// ---------------------------------------------------------------------------
// Medallas
// ---------------------------------------------------------------------------

test("una medalla sube de bronce a oro según su métrica", () => {
  const partidos = Array.from({ length: 10 }, (_, index) =>
    room({ id: `m${index}`, playedAt: daysAgo(60 + index), winner: "A" })
  );
  const summary = summarizeProgress(partidos, "me", NOW);

  const debut = summary.medals.find((medal) => medal.id === "debut")!;
  assert.equal(debut.value, 10);
  assert.equal(debut.tier, "plata");
  assert.equal(debut.nextThreshold, 50);
  assert.equal(debut.unlocked, true);
});

test("una medalla sin progreso queda bloqueada pero muestra su avance", () => {
  const summary = summarizeProgress([], "me", NOW);
  const social = summary.medals.find((medal) => medal.id === "social")!;

  assert.equal(social.tier, null);
  assert.equal(social.unlocked, false);
  assert.equal(social.progress, 0);
  assert.equal(social.nextThreshold, 3);
});

test("la medalla de oro deja de pedir siguiente umbral", () => {
  const partidos = Array.from({ length: 30 }, (_, index) =>
    room({ id: `m${index}`, playedAt: daysAgo(200 + index), winner: "A", rivals: [`rival-${index}`] })
  );
  const summary = summarizeProgress(partidos, "me", NOW);
  const social = summary.medals.find((medal) => medal.id === "social")!;

  assert.equal(social.tier, "oro");
  assert.equal(social.nextThreshold, null);
  assert.equal(social.progress, 1);
});

test("los dobles cuentan compañeros y suman su bonus", () => {
  const summary = summarizeProgress(
    [room({ playedAt: daysAgo(3), winner: "A", format: "doubles", partners: ["socio"], rivals: ["r1", "r2"] })],
    "me",
    NOW
  );

  assert.equal(summary.stats.doubles, 1);
  assert.equal(summary.stats.rivals, 2);
  const esperado =
    XP_RULES.playedMatch + XP_RULES.win + 2 * XP_RULES.setWon + 2 * XP_RULES.newRival + XP_RULES.doubles;
  assert.equal(summary.level.xp, esperado);
});

test("solo puntúan las reseñas escritas por el jugador", () => {
  const summary = summarizeProgress(
    [room({ playedAt: daysAgo(3), winner: "A", reviews: [review("me"), review("rival-1")] })],
    "me",
    NOW
  );

  assert.equal(summary.stats.reviewsGiven, 1);
});

test("los partidos a primera hora o de noche alimentan la medalla del reloj", () => {
  const summary = summarizeProgress(
    [
      room({ id: "amanecer", playedAt: daysAgo(5, 7), winner: "A" }),
      room({ id: "noche", playedAt: daysAgo(4, 22), winner: "A" }),
      room({ id: "tarde", playedAt: daysAgo(3, 18), winner: "A" })
    ],
    "me",
    NOW
  );

  assert.equal(summary.stats.earlyOrLate, 2);
});

test("el siguiente hito es el que está más cerca", () => {
  const summary = summarizeProgress([room({ playedAt: daysAgo(2), winner: "A" })], "me", NOW);
  const hito = nextMilestone(summary);

  assert.ok(hito);
  assert.equal(hito.remaining, 1);
});

test("un jugador sin partidos obtiene un resumen vacío y estable", () => {
  const summary = summarizeProgress([], "me", NOW);

  assert.equal(summary.level.level, 1);
  assert.equal(summary.level.xp, 0);
  assert.equal(summary.stats.winRate, null);
  assert.equal(summary.week.allClosed, false);
  assert.equal(summary.medals.length, 12);
  assert.deepEqual(summary.form, []);
});
