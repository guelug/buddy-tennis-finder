import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { assistantMatchSummary, assistantRanking, deduplicateInFlight } from "../src/lib/assistant-runtime";
import type { MatchRoom, Player, ValidatedRankingResult } from "../src/types";

test("el ranking del asistente usa puntos reales y el mismo ámbito regional", () => {
  const me = { id: "me", name: "Zoe", city: "Madrid", country: "España", level: "c", clubIds: [], profileComplete: true } as unknown as Player;
  const other = { ...me, id: "other", name: "Ana" };
  const outsider = { ...me, id: "outside", city: "Barcelona", name: "Aaa" };
  const result = { matchId: "match", city: "Madrid", division: "c", playerAId: "me", playerBId: "other", winnerId: "me", playedAt: "2026-09-15" } as ValidatedRankingResult;
  assert.deepEqual(assistantRanking(me, [other, outsider, me], [], [result]), { rank: 1, total: 2, points: 100 });
  assert.equal(assistantRanking(me, [other], [], [result]), null);
});

const room = (i: number, changes: Partial<MatchRoom> = {}): MatchRoom => ({
  id: String(i), playedAt: `2026-09-${String(i).padStart(2, "0")}`,
  teamA: { playerIds: ["me"], playerNames: ["Pedro"] },
  teamB: { playerIds: ["other"], playerNames: ["Rival"] },
  result: { winner: "A" }, status: "validated", ...changes
} as MatchRoom);

test("las estadísticas cuentan todo el historial, no solo los cinco recientes", () => {
  const rooms = Array.from({length: 8}, (_, i) => room(i + 1));
  const summary = assistantMatchSummary(rooms, "me");
  assert.equal(summary.wins, 8);
  assert.equal(summary.losses, 0);
  assert.deepEqual(summary.recentRooms.map(r => r.id), ["8", "7", "6", "5", "4"]);
  assert.equal(rooms[0].id, "1");
});

test("solo cuentan resultados validados del jugador, incluyendo equipo B", () => {
  const summary = assistantMatchSummary([room(1), room(2, {status: "disputed"}), room(3, {result: undefined})], "other");
  assert.equal(summary.wins, 0);
  assert.equal(summary.losses, 1);
  assert.deepEqual(assistantMatchSummary([room(1)], "outsider"), {wins: 0, losses: 0, recentRooms: []});
});

test("la disponibilidad comparte consultas simultáneas pero se refresca después", async () => {
  let available = false;
  let calls = 0;
  const read = deduplicateInFlight(async () => { calls++; return available; });
  const first = read();
  assert.equal(first, read());
  assert.equal(await first, false);
  available = true;
  assert.equal(await read(), true);
  assert.equal(calls, 2);
});

test("un fallo temporal no deja permanentemente bloqueada la disponibilidad", async () => {
  let calls = 0;
  const read = deduplicateInFlight(async () => { if (++calls === 1) throw new Error("temporary"); return true; });
  await assert.rejects(read());
  assert.equal(await read(), true);
});

test("las instrucciones nativas respetan el idioma y nombre elegidos", () => {
  const swift = readFileSync("modules/matchpoint-local-ai/ios/MatchPointLocalAIModule.swift", "utf8");
  const kotlin = readFileSync("modules/matchpoint-local-ai/android/src/main/java/com/matchpoint/localai/MatchPointLocalAIModule.kt", "utf8");
  assert.doesNotMatch(swift, /Responde en español|natural en español/);
  assert.doesNotMatch(kotlin, /Responde en español/);
  assert.match(swift, /nombre del asistente y el idioma/);
});
