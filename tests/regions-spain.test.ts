import assert from "node:assert/strict";
import { test } from "node:test";
import {
  CITIES_BY_COUNTRY,
  CITIES_BY_REGION,
  REGIONS_BY_COUNTRY,
  REGION_BY_CITY,
  citiesForSearch,
  clubs
} from "@/data/seed";

test("cada club tiene una ciudad dada de alta en su región", () => {
  for (const club of clubs) {
    const cities = CITIES_BY_COUNTRY[club.country as keyof typeof CITIES_BY_COUNTRY];
    assert.ok(cities, `país sin ciudades: ${club.country}`);
    assert.ok(
      cities.includes(club.city),
      `${club.name}: la ciudad "${club.city}" no está en ${club.country}`
    );
  }
});

test("toda ciudad ofrecida pertenece a una región", () => {
  for (const cities of Object.values(CITIES_BY_COUNTRY)) {
    for (const city of cities) {
      assert.ok(REGION_BY_CITY[city], `la ciudad "${city}" no tiene región`);
    }
  }
});

test("las regiones de un país no comparten ciudades", () => {
  const vistas = new Set<string>();
  for (const cities of Object.values(CITIES_BY_REGION)) {
    for (const city of cities) {
      assert.ok(!vistas.has(city), `la ciudad "${city}" está en dos regiones`);
      vistas.add(city);
    }
  }
});

test("buscar en toda la comunidad incluye los municipios vecinos", () => {
  const soloCiudad = citiesForSearch("Pallejà", false);
  const toda = citiesForSearch("Pallejà", true);
  assert.deepEqual(soloCiudad, ["Pallejà"]);
  assert.ok(toda.includes("Barcelona"), "Barcelona debería entrar en Catalunya");
  assert.ok(toda.includes("Castelldefels"));
  // La ciudad propia siempre va primero: es la más relevante.
  assert.equal(toda[0], "Pallejà");
});

test("una comunidad no arrastra ciudades de otra", () => {
  const aragon = citiesForSearch("Formigal", true);
  assert.ok(!aragon.includes("Barcelona"), "Formigal es Aragón, no Catalunya");
  assert.deepEqual(aragon, ["Formigal"]);
});

test("nunca se superan los 30 valores que admite un `in` de Firestore", () => {
  for (const cities of Object.values(CITIES_BY_REGION)) {
    for (const city of cities) {
      assert.ok(citiesForSearch(city, true).length <= 30, `demasiadas ciudades para ${city}`);
    }
  }
});

test("una ciudad desconocida no rompe la búsqueda", () => {
  assert.deepEqual(citiesForSearch("Ciudad Inventada", true), ["Ciudad Inventada"]);
  assert.deepEqual(citiesForSearch(undefined, true), []);
});

test("España ofrece Catalunya y Aragón con sus ciudades", () => {
  assert.deepEqual(REGIONS_BY_COUNTRY["España"], ["Catalunya", "Aragón"]);
  assert.ok(CITIES_BY_COUNTRY["España"].includes("Castelldefels"));
  assert.ok(CITIES_BY_COUNTRY["España"].includes("Formigal"));
});
