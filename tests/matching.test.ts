import assert from "node:assert/strict";
import test from "node:test";
import { compatibilityPct, isLevelCompatible, rankCandidates, rankOpenProposals } from "../src/lib/matching";
import type { MatchProposal, Player, SearchPreferences } from "../src/types";

function player(overrides: Partial<Player> = {}): Player {
  return {
    id: "me",
    name: "Jugador",
    age: 32,
    gender: "other",
    clubIds: ["club-1"],
    city: "Madrid",
    country: "España",
    latitude: 40.4,
    longitude: -3.7,
    level: "c",
    preferredFormats: ["singles"],
    availability: [{ day: "martes", ranges: ["18:00-20:00"] }],
    bio: "",
    rating: 3,
    responseRate: 80,
    languages: ["Español"],
    profileComplete: true,
    ...overrides
  };
}

const preferences: SearchPreferences = {
  level: "any",
  formats: ["singles"],
  ageMin: 18,
  ageMax: 80,
  requireSharedAvailability: true
};

test("solo considera compatibles niveles iguales o adyacentes", () => {
  assert.equal(isLevelCompatible("c", "b"), true);
  assert.equal(isLevelCompatible("c", "a"), false);
  assert.equal(isLevelCompatible("novato", "d"), true);
});

test("calcula el solapamiento real y excluye al usuario y perfiles de muestra", () => {
  const current = player();
  const compatible = player({
    id: "rival",
    name: "Rival",
    availability: [{ day: "martes", ranges: ["19:00-21:00"] }]
  });
  const incompatible = player({ id: "sin-hueco", availability: [{ day: "jueves", ranges: ["10:00-11:00"] }] });
  const demo = player({ id: "demo-rival", isDemo: true });
  const result = rankCandidates(current, [current, incompatible, demo, compatible], preferences);

  assert.deepEqual(result.map((item) => item.player.id), ["rival"]);
  assert.deepEqual(result[0]?.sharedSlots, ["martes 19:00-20:00"]);
});

test("las propuestas abiertas excluyen propias, caducadas y niveles incompatibles", () => {
  const current = player();
  const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  const past = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const proposal = (overrides: Partial<MatchProposal>): MatchProposal => ({
    id: "valid",
    fromPlayerId: "rival",
    acceptedByPlayerId: null,
    clubId: "club-1",
    proposedAt: new Date().toISOString(),
    startsAt: future,
    reservationTime: "18:00-19:00",
    court: 1,
    status: "proposed",
    format: "singles",
    division: "b",
    message: "Partido",
    ...overrides
  });
  const ranked = rankOpenProposals(current, [
    proposal({}),
    proposal({ id: "mine", fromPlayerId: "me" }),
    proposal({ id: "past", startsAt: past }),
    proposal({ id: "far-level", division: "a" }),
    proposal({ id: "taken", acceptedByPlayerId: "another", status: "accepted" })
  ], [{ id: "club-1", name: "Club Central" }]);

  assert.deepEqual(ranked.map((item) => item.proposal.id), ["valid"]);
  assert.equal(ranked[0]?.clubName, "Club Central");
  assert.equal(ranked[0]?.sharedClub, true);
});

test("los niveles elegidos por el organizador controlan los partidos informales", () => {
  const proposal: MatchProposal = {
    id: "niveles",
    fromPlayerId: "owner",
    acceptedByPlayerId: null,
    clubId: "club-1",
    proposedAt: new Date().toISOString(),
    startsAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    reservationTime: "18:00-19:00",
    court: 1,
    status: "proposed",
    format: "singles",
    division: "c",
    acceptedLevels: ["novato", "d"],
    message: "Partido informal"
  };
  const novice = player({ id: "novice", level: "novato" });
  const advanced = player({ id: "advanced", level: "c" });
  const clubs = [{ id: "club-1", name: "Club Central" }];
  assert.equal(rankOpenProposals(novice, [proposal], clubs).length, 1);
  assert.equal(rankOpenProposals(advanced, [proposal], clubs).length, 0);
});

test("el porcentaje mostrado siempre queda entre 20 y 99", () => {
  assert.equal(compatibilityPct(-10), 20);
  assert.equal(compatibilityPct(500), 99);
});
