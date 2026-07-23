/**
 * MatchPoint Tennis localization runtime.
 *
 * Locale catalogs live in `i18n/*.json`; English is the canonical fallback.
 * The provider restores an explicit user choice first, otherwise it starts from
 * the device/browser locale. `t` also supports typed interpolation parameters.
 */
import * as React from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Platform } from "react-native";
import {
  detectDeviceLanguage,
  DICTIONARIES,
  FALLBACK_LANGUAGE,
  normalizeLanguageCode,
  SUPPORTED_LANGUAGES,
  translate,
  type LanguageCode
} from "@/lib/i18n-catalog";

export type { LanguageCode } from "@/lib/i18n-catalog";
export { SUPPORTED_LANGUAGES } from "@/lib/i18n-catalog";

const storageKey = "matchpoint-language";

type TranslationParams = Record<string, string | number>;
type I18nContextValue = {
  lang: LanguageCode;
  locale: LanguageCode;
  setLang: (lang: LanguageCode) => void;
  t: (key: string, params?: TranslationParams) => string;
};

const I18nContext = React.createContext<I18nContextValue | null>(null);

export function I18nProvider({ children }: React.PropsWithChildren) {
  const [lang, setLangState] = React.useState<LanguageCode>(detectDeviceLanguage);

  React.useEffect(() => {
    let active = true;
    const restore = async () => {
      try {
        const stored = Platform.OS === "web" && typeof window !== "undefined"
          ? window.localStorage.getItem(storageKey)
          : await AsyncStorage.getItem(storageKey);
        const restored = normalizeLanguageCode(stored);
        if (active && restored) setLangState(restored);
      } catch {
        // Storage is optional; keep the detected device language for this session.
      }
    };
    void restore();
    return () => { active = false; };
  }, []);

  const setLang = React.useCallback((next: LanguageCode) => {
    setLangState(next);
    if (Platform.OS === "web" && typeof window !== "undefined") {
      try {
        window.localStorage.setItem(storageKey, next);
      } catch {
        // Keep the in-memory preference when browser storage is blocked.
      }
    } else {
      void AsyncStorage.setItem(storageKey, next).catch(() => {});
    }
  }, []);

  const t = React.useCallback(
    (key: string, params?: TranslationParams) => translate(
      DICTIONARIES[lang],
      DICTIONARIES[FALLBACK_LANGUAGE],
      key,
      params
    ),
    [lang]
  );

  React.useEffect(() => {
    if (Platform.OS === "web" && typeof document !== "undefined") {
      document.documentElement.lang = lang;
    }
  }, [lang]);

  const value = React.useMemo(
    () => ({ lang, locale: lang, setLang, t }),
    [lang, setLang, t]
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const value = React.useContext(I18nContext);
  if (!value) throw new Error("useI18n must be used inside I18nProvider");
  return value;
}
