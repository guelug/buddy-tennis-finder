import assert from "node:assert/strict";
import test from "node:test";
import { buildProvisionalRankings } from "../src/data/rankings";
import type { Club, Player } from "../src/types";

const club: Club = {
  id: "club-1",
  name: "Club Central",
  city: "Madrid",
  country: "España",
  latitude: 40.4,
  longitude: -3.7,
  courts: 4
};

function player(id: string, rating: number, responseRate: number, profileComplete = true): Player {
  return {
    id,
    name: `Jugador ${id}`,
    age: 30,
    gender: "other",
    clubIds: [club.id],
    city: club.city,
    country: club.country,
    latitude: club.latitude,
    longitude: club.longitude,
    level: "c",
    preferredFormats: ["singles"],
    availability: [],
    bio: "",
    rating,
    responseRate,
    languages: ["Español"],
    profileComplete
  };
}

test("el ranking provisional solo usa perfiles completos y señales reales", () => {
  const rankings = buildProvisionalRankings([
    player("b", 4, 80),
    player("a", 4, 95),
    player("incompleto", 5, 100, false)
  ], [club]);

  assert.deepEqual(rankings.c.map((entry) => entry.playerId), ["a", "b"]);
  assert.deepEqual(rankings.c.map((entry) => entry.rank), [1, 2]);
  assert.equal(rankings.c[0]?.clubName, club.name);
  assert.equal(rankings.c[0]?.wins, 0);
  assert.equal(rankings.c[0]?.losses, 0);
});
