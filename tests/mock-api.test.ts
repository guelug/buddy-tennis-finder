import assert from "node:assert/strict";
import test from "node:test";
import { getHomeData } from "../src/lib/mock-api";

test("los datos semilla son pasivos y no crean partidos ficticios", async () => {
  const home = await getHomeData();
  const examples = home.players.filter((player) => player.id !== home.currentPlayer.id);

  assert.ok(examples.length > 0);
  assert.ok(examples.every((player) => player.isDemo === true));
  assert.ok(examples.every((player) => player.responseRate === 0));
  assert.deepEqual(home.proposals, []);
});
