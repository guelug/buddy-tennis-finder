import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { rankCandidates } from "../src/lib/matching";
import { scopeRankingToArea } from "../src/data/rankings";
import {
  allPublicLeagueIds,
  findPublicLeague,
  publicLeagueForDivision,
  publicLeagueIdsFor
} from "../src/data/competition-hub";
import type { Player, RankingEntry, SearchPreferences } from "../src/types";

function player(overrides: Partial<Player> = {}): Player {
  return {
    id: "me",
    name: "Jugador",
    age: 32,
    gender: "other",
    clubIds: ["club-1"],
    city: "Barcelona",
    country: "España",
    latitude: 41.4,
    longitude: 2.1,
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
  ageMin: 13,
  ageMax: 100,
  requireSharedAvailability: false
};

function entry(overrides: Partial<RankingEntry> = {}): RankingEntry {
  return {
    rank: 1,
    playerId: "p",
    playerName: "P",
    division: "c",
    tier: "bronce",
    points: 0,
    wins: 0,
    losses: 0,
    streak: 0,
    ...overrides
  };
}

test("el buscador de rivales nunca cruza ciudades", () => {
  const me = player({ id: "me", city: "Barcelona", country: "España" });
  const others = [
    player({ id: "vecino", name: "Vecino", city: "Barcelona", country: "España" }),
    player({ id: "lejano", name: "Lejano", city: "Ciudad de Guatemala", country: "Guatemala" })
  ];
  const ids = rankCandidates(me, others, preferences).map((candidate) => candidate.player.id);
  assert.deepEqual(ids, ["vecino"]);
});

test("la ciudad se compara sin acentos ni mayúsculas", () => {
  const me = player({ id: "me", city: "Ciudad de Guatemala", country: "Guatemala" });
  const others = [player({ id: "otro", city: "ciudad de guatemala", country: "Guatemala" })];
  assert.equal(rankCandidates(me, others, preferences).length, 1);
});

test("un perfil sin ciudad se agrupa por país en vez de desaparecer", () => {
  const me = player({ id: "me", city: "Barcelona", country: "España" });
  const others = [
    player({ id: "sin-ciudad", city: "", country: "España" }),
    player({ id: "otro-pais", city: "", country: "Guatemala" })
  ];
  const ids = rankCandidates(me, others, preferences).map((candidate) => candidate.player.id);
  assert.deepEqual(ids, ["sin-ciudad"]);
});

test("el ranking regional filtra por ciudad y renumera desde 1", () => {
  const entries = [
    entry({ rank: 1, playerId: "a", city: "Ciudad de Guatemala", country: "Guatemala" }),
    entry({ rank: 2, playerId: "b", city: "Barcelona", country: "España" }),
    entry({ rank: 3, playerId: "c", city: "Barcelona", country: "España" })
  ];
  const regional = scopeRankingToArea(entries, "Barcelona", "España");
  assert.deepEqual(regional.map((item) => [item.playerId, item.rank]), [["b", 1], ["c", 2]]);
});

test("el ranking global no se filtra cuando no hay región conocida", () => {
  const entries = [entry({ playerId: "a", city: "Barcelona" }), entry({ playerId: "b", city: "Lima" })];
  assert.equal(scopeRankingToArea(entries, undefined, undefined).length, 2);
});

test("las ligas públicas están separadas por ciudad", () => {
  const barcelona = publicLeagueForDivision("c", "Barcelona");
  const guatemala = publicLeagueForDivision("c", "Ciudad de Guatemala");
  assert.notEqual(barcelona.id, guatemala.id);
  assert.equal(barcelona.id, "l-c-individual-barcelona");
  assert.match(barcelona.name, /Barcelona/);
});

test("una ciudad sin liga propia cae en la liga histórica sin sufijo", () => {
  assert.equal(publicLeagueForDivision("c", "Lima").id, "l-c-individual");
  assert.equal(publicLeagueForDivision("c", undefined).id, "l-c-individual");
});

test("las inscripciones anteriores a la separación regional siguen contando", () => {
  const ids = publicLeagueIdsFor("c", "Barcelona");
  assert.ok(ids.includes("l-c-individual-barcelona"), "debe aceptar el id con ciudad");
  assert.ok(ids.includes("l-c-individual"), "debe aceptar el id histórico");
});

test("findPublicLeague resuelve ids con y sin sufijo de ciudad", () => {
  assert.equal(findPublicLeague("l-c-individual-barcelona")?.division, "c");
  assert.equal(findPublicLeague("l-c-individual")?.division, "c");
  assert.equal(findPublicLeague("l-c-individual-lima"), null);
  assert.equal(findPublicLeague(undefined), null);
});

test("firestore.rules acepta exactamente los ids de liga que genera la app", () => {
  // Los tests se ejecutan desde la raíz del repo (`npm test`).
  const rules = readFileSync("firestore.rules", "utf8");
  const missing = allPublicLeagueIds().filter((id) => !rules.includes(`"${id}"`));
  assert.deepEqual(
    missing,
    [],
    `Las reglas de Firestore no permiten estas ligas: ${missing.join(", ")}. ` +
      "Regenera la lista de firestore.rules con allPublicLeagueIds()."
  );
});
