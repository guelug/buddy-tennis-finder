import * as React from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Platform, useColorScheme } from "react-native";
import { applyThemeColors } from "./tokens";

type ThemeMode = "dark" | "light";
/** Preferencia del usuario: sigue al sistema o fuerza un modo. */
export type ThemePreference = "system" | ThemeMode;

type ThemeModeContextValue = {
  /** Modo resuelto (tras aplicar la preferencia "system"). */
  mode: ThemeMode;
  isLight: boolean;
  /** Preferencia guardada: system | dark | light. */
  preference: ThemePreference;
  setPreference: (preference: ThemePreference) => void;
  setMode: (mode: ThemeMode) => void;
  toggleMode: () => void;
};

const ThemeModeContext = React.createContext<ThemeModeContextValue | null>(null);
const storageKey = "matchpoint-theme-mode";

function isThemePreference(value: unknown): value is ThemePreference {
  return value === "system" || value === "light" || value === "dark";
}

export function ThemeModeProvider({ children }: React.PropsWithChildren) {
  const systemScheme = useColorScheme();
  const [preference, setPreferenceState] = React.useState<ThemePreference>("system");

  React.useEffect(() => {
    let active = true;
    const restoreMode = async () => {
      try {
        const stored = Platform.OS === "web" && typeof window !== "undefined"
          ? window.localStorage.getItem(storageKey)
          : await AsyncStorage.getItem(storageKey);
        if (active && isThemePreference(stored)) setPreferenceState(stored);
      } catch {
        // El tema del sistema sigue siendo un fallback válido si el storage no está disponible.
      }
    };
    void restoreMode();
    return () => { active = false; };
  }, []);

  const setPreference = React.useCallback((next: ThemePreference) => {
    setPreferenceState(next);
    if (Platform.OS === "web" && typeof window !== "undefined") {
      try {
        window.localStorage.setItem(storageKey, next);
      } catch {
        // Navegadores con storage bloqueado: conservamos el modo durante la sesión.
      }
    } else {
      void AsyncStorage.setItem(storageKey, next).catch(() => {});
    }
  }, []);

  const mode: ThemeMode = preference === "system" ? (systemScheme === "light" ? "light" : "dark") : preference;

  const setMode = React.useCallback((nextMode: ThemeMode) => {
    setPreference(nextMode);
  }, [setPreference]);

  const toggleMode = React.useCallback(() => {
    setPreference(mode === "light" ? "dark" : "light");
  }, [mode, setPreference]);

  const value = React.useMemo(
    () => ({ mode, isLight: mode === "light", preference, setPreference, setMode, toggleMode }),
    [mode, preference, setPreference, setMode, toggleMode]
  );

  applyThemeColors(mode);

  return (
    <ThemeModeContext.Provider value={value}>
      {children}
    </ThemeModeContext.Provider>
  );
}

export function useThemeMode() {
  const value = React.useContext(ThemeModeContext);
  if (!value) {
    throw new Error("useThemeMode debe usarse dentro de ThemeModeProvider");
  }
  return value;
}
