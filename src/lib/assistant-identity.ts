/**
 * Identidad del chat: la personalidad del asistente (Mia/Mateo) y la identidad
 * del jugador son cosas distintas y nunca deben mezclarse.
 *
 * Las preguntas de identidad se responden aquí de forma determinista, sin pasar
 * por el modelo local: los modelos pequeños son justo el caso donde se mezclan
 * los nombres y el asistente acaba diciendo "Soy <nombre del jugador>".
 *
 * Este módulo no importa nada de React Native ni Firebase: es lógica pura y se
 * puede testear en Node sin mocks.
 */

export type IdentityIntent = "assistant" | "user" | null;

const IDENTITY_PATTERNS: Array<{ intent: Exclude<IdentityIntent, null>; words: string[] }> = [
  // Primero la identidad del jugador: "¿sabes quién soy?" gana a cualquier genérico.
  { intent: "user", words: ["quien soy", "me conoces", "sabes de mi", "who am i", "know who i am", "do you know me"] },
  { intent: "assistant", words: ["quien eres", "como te llamas", "cual es tu nombre", "tu nombre", "que eres tu", "presentate", "who are you", "your name", "what is your name"] }
];

export function detectIdentityIntent(question: string): IdentityIntent {
  const strip = (value: string) => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  const normalized = strip(question.toLocaleLowerCase("es")).trim();
  for (const { intent, words } of IDENTITY_PATTERNS) {
    if (words.some((word) => normalized.includes(strip(word)))) return intent;
  }
  return null;
}

export function fillTemplate(template: string, values: Record<string, string | number>) {
  return Object.entries(values).reduce(
    (text, [token, value]) => text.replaceAll(`{${token}}`, String(value)),
    template
  );
}

export type IdentityParams = {
  /** Nombre del Match Buddy elegido por el usuario (Mia o Mateo). */
  assistantName: string;
  playerName: string;
  divisionLabel: string;
  city: string;
};

/**
 * Texto de la respuesta de identidad. "assistant" = quién es el asistente;
 * "user" = quién es el jugador. Nunca se cruzan.
 */
export function identityAnswerText(intent: Exclude<IdentityIntent, null>, params: IdentityParams, t: (key: string) => string): string {
  if (intent === "assistant") {
    return fillTemplate(t("assistant.answer.assistantIdentity"), { name: params.assistantName });
  }
  return fillTemplate(t("assistant.answer.userIdentity"), {
    name: params.playerName,
    division: params.divisionLabel,
    city: params.city
  });
}
