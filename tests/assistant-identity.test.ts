import assert from "node:assert/strict";
import test from "node:test";
import { detectIdentityIntent, identityAnswerText } from "../src/lib/assistant-identity";
import es from "../i18n/es.json";

// Catálogo real en español: las respuestas de identidad se componen con t().
const t = (key: string) => (es as Record<string, string>)[key] ?? key;

const pedro = {
  assistantName: "Andrea",
  playerName: "Pedro Caparros",
  divisionLabel: "C",
  city: "Barcelona"
};

test("detecta la pregunta sobre la identidad del jugador", () => {
  assert.equal(detectIdentityIntent("¿Sabes quién soy?"), "user");
  assert.equal(detectIdentityIntent("sabes quien soy"), "user");
  assert.equal(detectIdentityIntent("¿Me conoces?"), "user");
  assert.equal(detectIdentityIntent("Do you know who I am?"), "user");
});

test("detecta la pregunta sobre la identidad del asistente", () => {
  assert.equal(detectIdentityIntent("¿Quién eres?"), "assistant");
  assert.equal(detectIdentityIntent("¿Cómo te llamas?"), "assistant");
  assert.equal(detectIdentityIntent("¿Cuál es tu nombre?"), "assistant");
  assert.equal(detectIdentityIntent("who are you?"), "assistant");
});

test("las preguntas de tenis no son preguntas de identidad", () => {
  assert.equal(detectIdentityIntent("¿Cuáles fueron mis últimos resultados?"), null);
  assert.equal(detectIdentityIntent("¿En qué puesto del ranking estoy?"), null);
  assert.equal(detectIdentityIntent("¿Cómo va mi liga?"), null);
});

test("¿sabes quién soy? responde con el nombre del jugador, no del asistente", () => {
  const text = identityAnswerText("user", pedro, t);
  assert.ok(text.includes("Eres Pedro Caparros"), text);
  assert.ok(!text.includes("Soy Pedro"), text);
});

test("¿quién eres? se presenta con el nombre del Match Buddy elegido", () => {
  const andrea = identityAnswerText("assistant", pedro, t);
  assert.ok(andrea.startsWith("Soy Andrea"), andrea);

  const faker = identityAnswerText("assistant", { ...pedro, assistantName: "Faker" }, t);
  assert.ok(faker.startsWith("Soy Faker"), faker);
});

test("la identidad del asistente nunca usa el nombre del jugador", () => {
  const text = identityAnswerText("assistant", pedro, t);
  assert.ok(!text.includes("Pedro"), text);
});

test("la identidad del jugador incluye división y ciudad del perfil", () => {
  const text = identityAnswerText("user", pedro, t);
  assert.ok(text.includes("C") && text.includes("Barcelona"), text);
});
