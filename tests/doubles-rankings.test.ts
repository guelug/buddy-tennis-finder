import assert from "node:assert/strict";
import { test } from "node:test";
import { buildDoublesRankings, pairKey, suggestedPartnerId } from "@/data/rankings";
import type { DoublesRankingResult } from "@/types";

const names = new Map([
  ["ana", "Ana"],
  ["luis", "Luis"],
  ["marta", "Marta"],
  ["diego", "Diego"],
  ["sofia", "Sofía"]
]);

function match(
  matchId: string,
  teamAIds: string[],
  teamBIds: string[],
  winnerTeam: "A" | "B"
): DoublesRankingResult {
  return {
    matchId,
    city: "Madrid",
    division: "c",
    teamAIds,
    teamBIds,
    winnerTeam,
    playedAt: "2026-07-01T10:00:00.000Z"
  };
}

test("pairKey identifica a la pareja sin depender del orden", () => {
  assert.equal(pairKey(["ana", "luis"]), pairKey(["luis", "ana"]));
  assert.notEqual(pairKey(["ana", "luis"]), pairKey(["ana", "marta"]));
});

test("la pareja acumula victorias y derrotas jugando junta", () => {
  const table = buildDoublesRankings([
    match("m1", ["ana", "luis"], ["marta", "diego"], "A"),
    match("m2", ["ana", "luis"], ["marta", "diego"], "A"),
    match("m3", ["ana", "luis"], ["marta", "diego"], "B")
  ], names);

  const top = table.c[0];
  assert.deepEqual(top.playerIds, ["ana", "luis"]);
  assert.equal(top.wins, 2);
  assert.equal(top.losses, 1);
  assert.equal(top.played, 3);
  assert.equal(top.rank, 1);

  const rival = table.c.find((entry) => entry.pairId === pairKey(["marta", "diego"]));
  assert.equal(rival?.wins, 1);
  assert.equal(rival?.losses, 2);
});

test("repetir compañero puntúa más que cambiar de pareja con el mismo palmarés", () => {
  // Ana repite con Luis; Marta gana lo mismo pero con compañeros distintos.
  const table = buildDoublesRankings([
    match("m1", ["ana", "luis"], ["x1", "x2"], "A"),
    match("m2", ["ana", "luis"], ["x3", "x4"], "A"),
    match("m3", ["marta", "diego"], ["y1", "y2"], "A"),
    match("m4", ["marta", "sofia"], ["y3", "y4"], "A")
  ], names);

  const constante = table.c.find((entry) => entry.pairId === pairKey(["ana", "luis"]));
  const rotativa = table.c.find((entry) => entry.pairId === pairKey(["marta", "diego"]));
  assert.ok(constante && rotativa);
  // Dos victorias juntas pesan más que una suelta de cada pareja.
  assert.ok(constante.points > rotativa.points);
  assert.equal(table.c[0].pairId, pairKey(["ana", "luis"]));
});

test("cambiar de compañero no arrastra el histórico de la pareja anterior", () => {
  const table = buildDoublesRankings([
    match("m1", ["ana", "luis"], ["x1", "x2"], "A"),
    match("m2", ["ana", "marta"], ["x3", "x4"], "A")
  ], names);

  const conLuis = table.c.find((entry) => entry.pairId === pairKey(["ana", "luis"]));
  const conMarta = table.c.find((entry) => entry.pairId === pairKey(["ana", "marta"]));
  assert.equal(conLuis?.wins, 1);
  assert.equal(conMarta?.wins, 1);
  assert.equal(conLuis?.played, 1);
});

test("una pareja incompleta no entra en la clasificación", () => {
  const table = buildDoublesRankings([
    match("m1", ["ana"], ["marta", "diego"], "B")
  ], names);
  assert.equal(table.c.some((entry) => entry.playerIds.includes("ana")), false);
  assert.equal(table.c.length, 1);
});

test("una pareja con una cuenta eliminada no reaparece como jugador anónimo", () => {
  const table = buildDoublesRankings([
    match("m1", ["deleted-user", "luis"], ["marta", "diego"], "B")
  ], names);
  assert.equal(table.c.some((entry) => entry.playerIds.includes("deleted-user")), false);
  assert.equal(table.c.some((entry) => entry.pairId === pairKey(["marta", "diego"])), true);
});

test("el compañero sugerido es con quien más ha jugado", () => {
  const results = [
    match("m1", ["ana", "luis"], ["x1", "x2"], "A"),
    match("m2", ["ana", "luis"], ["x3", "x4"], "B"),
    match("m3", ["ana", "marta"], ["x5", "x6"], "A")
  ];
  assert.equal(suggestedPartnerId("ana", results), "luis");
  assert.equal(suggestedPartnerId("nadie", results), null);
});
