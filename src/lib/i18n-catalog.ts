import ca from "../../i18n/ca.json";
import de from "../../i18n/de.json";
import en from "../../i18n/en.json";
import es from "../../i18n/es.json";
import esGT from "../../i18n/es-GT.json";
import eu from "../../i18n/eu.json";
import gl from "../../i18n/gl.json";
import ja from "../../i18n/ja.json";
import ko from "../../i18n/ko.json";
import ptBR from "../../i18n/pt-BR.json";
import tr from "../../i18n/tr.json";
import zhCN from "../../i18n/zh-CN.json";

export const languageCodes = [
  "en",
  "ca",
  "gl",
  "eu",
  "ko",
  "ja",
  "zh-CN",
  "es-GT",
  "de",
  "pt-BR",
  "tr"
] as const;

export type LanguageCode = (typeof languageCodes)[number];
export type Dictionary = Record<string, string>;

export const SUPPORTED_LANGUAGES: ReadonlyArray<{ code: LanguageCode; label: string }> = [
  { code: "en", label: "English" },
  { code: "ca", label: "Català" },
  { code: "gl", label: "Galego" },
  { code: "eu", label: "Euskara" },
  { code: "ko", label: "한국어" },
  { code: "ja", label: "日本語" },
  { code: "zh-CN", label: "简体中文" },
  { code: "es-GT", label: "Español (Guatemala)" },
  { code: "de", label: "Deutsch" },
  { code: "pt-BR", label: "Português (Brasil)" },
  { code: "tr", label: "Türkçe" }
];

export const DICTIONARIES: Record<LanguageCode, Dictionary> = {
  en,
  ca,
  gl,
  eu,
  ko,
  ja,
  "zh-CN": zhCN,
  "es-GT": esGT,
  de,
  "pt-BR": ptBR,
  tr
};

export const FALLBACK_LANGUAGE: LanguageCode = "en";

const baseLanguageAliases: Partial<Record<string, LanguageCode>> = {
  ca: "ca",
  de: "de",
  en: "en",
  es: "es-GT",
  eu: "eu",
  gl: "gl",
  ja: "ja",
  ko: "ko",
  pt: "pt-BR",
  tr: "tr",
  zh: "zh-CN"
};

export function normalizeLanguageCode(value: unknown): LanguageCode | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().replace(/_/g, "-");
  const exact = languageCodes.find((code) => code.toLowerCase() === normalized.toLowerCase());
  if (exact) return exact;
  return baseLanguageAliases[normalized.split("-")[0].toLowerCase()] ?? null;
}

export function detectDeviceLanguage(): LanguageCode {
  try {
    const deviceLocale = Intl.DateTimeFormat().resolvedOptions().locale;
    return normalizeLanguageCode(deviceLocale) ?? FALLBACK_LANGUAGE;
  } catch {
    return FALLBACK_LANGUAGE;
  }
}

export function translate(
  dictionary: Dictionary,
  fallback: Dictionary,
  key: string,
  params?: Record<string, string | number>
): string {
  const template = dictionary[key] ?? fallback[key] ?? key;
  if (!params) return template;
  return template.replace(/\{([A-Za-z0-9_]+)\}/g, (placeholder, name: string) => {
    const replacement = params[name];
    return replacement === undefined ? placeholder : String(replacement);
  });
}

export { es };
