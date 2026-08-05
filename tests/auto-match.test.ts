import assert from "node:assert/strict";
import test from "node:test";
import { findAutoMatch, rankTeamSeekers, type TeamSeeker } from "../src/lib/auto-match";

function seeker(overrides: Partial<TeamSeeker> = {}): TeamSeeker {
  return {
    id: "me",
    name: "Pedro",
    level: "c",
    city: "Ciudad de Guatemala",
    clubIds: ["club-aleman-gt"],
    seekingSince: "2026-08-01T10:00:00.000Z",
    ...overrides
  };
}

test("empareja con el buscador más antiguo de la misma ciudad y nivel compatible", () => {
  const first = seeker({ id: "first", name: "Ana", seekingSince: "2026-07-30T09:00:00.000Z" });
  const second = seeker({ id: "second", name: "Luis", seekingSince: "2026-07-31T09:00:00.000Z" });
  const match = findAutoMatch(seeker(), [second, first]);
  assert.equal(match?.id, "first");
});

test("nivel adyacente también empareja (c con b o d)", () => {
  const adjacent = seeker({ id: "adjacent", level: "b" });
  assert.equal(findAutoMatch(seeker(), [adjacent])?.id, "adjacent");
});

test("nivel demasiado lejano no empareja (c con a)", () => {
  const far = seeker({ id: "far", level: "a" });
  assert.equal(findAutoMatch(seeker(), [far]), null);
});

test("otra ciudad no empareja", () => {
  const otherCity = seeker({ id: "other", city: "Barcelona" });
  assert.equal(findAutoMatch(seeker(), [otherCity]), null);
});

test("nunca se empareja consigo mismo", () => {
  assert.equal(findAutoMatch(seeker(), [seeker()]), null);
});

test("a igualdad de antigüedad gana quien comparte club", () => {
  const sameTime = "2026-07-30T09:00:00.000Z";
  const sharedClub = seeker({ id: "shared", clubIds: ["club-aleman-gt"], seekingSince: sameTime });
  const noClub = seeker({ id: "noclub", clubIds: ["otro-club"], seekingSince: sameTime });
  assert.equal(findAutoMatch(seeker(), [noClub, sharedClub])?.id, "shared");
});

test("rankTeamSeekers excluye al propio buscador y ordena club compartido primero", () => {
  const viewer = seeker({ id: "viewer" });
  const shared = seeker({ id: "shared", clubIds: ["club-aleman-gt"], seekingSince: "2026-08-02T00:00:00.000Z" });
  const older = seeker({ id: "older", clubIds: ["otro"], seekingSince: "2026-07-25T00:00:00.000Z" });
  const ordered = rankTeamSeekers(viewer, [older, viewer, shared]);
  assert.deepEqual(ordered.map((item) => item.id), ["shared", "older"]);
});
