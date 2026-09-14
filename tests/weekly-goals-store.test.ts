import assert from "node:assert/strict";
import test from "node:test";
import { createWeeklyGoalsStore } from "../src/lib/weekly-goals-store";
import { DEFAULT_WEEKLY_GOALS } from "../src/lib/gamification";

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: Error) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

test("los objetivos nuevos prevalecen sobre una lectura antigua compartida", async () => {
  const disk = deferred<string | null>();
  let reads = 0;
  const store = createWeeklyGoalsStore({ getItem: () => { reads++; return disk.promise; }, setItem: async () => {} });
  const first = store.load();
  const second = store.load();
  const next = { ...DEFAULT_WEEKLY_GOALS, play: 9 };
  await store.save(next);
  disk.resolve(JSON.stringify(DEFAULT_WEEKLY_GOALS));
  assert.deepEqual(await first, next);
  assert.deepEqual(await second, next);
  assert.deepEqual(store.get(), next);
  assert.equal(reads, 1);
});

test("un error de lectura tardío no borra los objetivos elegidos", async () => {
  const disk = deferred<string | null>();
  const store = createWeeklyGoalsStore({ getItem: () => disk.promise, setItem: async () => {} });
  const loading = store.load();
  const next = { ...DEFAULT_WEEKLY_GOALS, connect: 10 };
  await store.save(next);
  disk.reject(new Error("offline storage"));
  assert.deepEqual(await loading, next);
});

test("guarda cambios rápidos en orden y continúa después de un fallo", async () => {
  const first = deferred<void>();
  const writes: string[] = [];
  const store = createWeeklyGoalsStore({ getItem: async () => null, setItem: async (_key, value) => {
    writes.push(value);
    if (writes.length === 1) await first.promise;
  } });
  const a = store.save({ ...store.get(), play: 4 });
  const b = store.save({ ...store.get(), connect: 8 });
  await Promise.resolve();
  assert.equal(writes.length, 1);
  first.reject(new Error("disk full"));
  await Promise.all([a, b]);
  assert.deepEqual(JSON.parse(writes[1]), { ...DEFAULT_WEEKLY_GOALS, play: 4, connect: 8 });
  assert.deepEqual(store.get(), JSON.parse(writes[1]));
});

test("restaura objetivos, notifica a todas las pantallas y permite desuscribirse", async () => {
  const next = { ...DEFAULT_WEEKLY_GOALS, play: 5 };
  const store = createWeeklyGoalsStore({ getItem: async () => JSON.stringify(next), setItem: async () => {} });
  const seen: unknown[] = [];
  const stop = store.subscribe((value) => seen.push(value));
  await store.load();
  assert.deepEqual(seen, [next]);
  stop();
  await store.save(DEFAULT_WEEKLY_GOALS);
  assert.equal(seen.length, 1);
});

test("datos corruptos o fuera de rango se normalizan sin bloquear los anillos", async () => {
  for (const value of ["not json", "null", '{"play":-4,"compete":100,"connect":"bad"}']) {
    const store = createWeeklyGoalsStore({ getItem: async () => value, setItem: async () => {} });
    const result = await store.load();
    assert.ok(result.play >= 1 && result.play <= 14);
    assert.ok(result.compete >= 2 && result.compete <= 40);
    assert.equal(result.connect, DEFAULT_WEEKLY_GOALS.connect);
  }
});
