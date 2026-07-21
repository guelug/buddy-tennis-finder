import { Platform } from "react-native";
import { useBreakpoint } from "./layout";

/**
 * Distingue web vs app nativa para aplicar patrones de UI distintos.
 * Web → dashboard, grillas, sidebar. Nativo → listas, heroes, tabs segmentados.
 */
export function usePlatformLayout() {
  const bp = useBreakpoint();
  const isWeb = Platform.OS === "web";
  const isNative = !isWeb;

  return {
    ...bp,
    isWeb,
    isNative,
    /** Web en viewport de escritorio (≥1024). */
    isWebDesktop: isWeb && bp.isDesktop,
    /** Web en viewport ancho (≥768). */
    isWebWide: isWeb && bp.isWide
  };
}