import { Platform, StatusBar, useWindowDimensions } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

/**
 * Alto seguro superior con fallback Android: algunos OEM (EMUI/Huawei) reportan
 * insets.top = 0 con status bar translúcida y el contenido queda debajo.
 * StatusBar.currentHeight sí es fiable en esos dispositivos.
 */
export function statusBarTopInset(insetTop: number) {
  const androidStatusBar = Platform.OS === "android" ? (StatusBar.currentHeight ?? 0) : 0;
  return Math.max(insetTop, androidStatusBar, 0);
}

/**
 * Breakpoints y anchos de contenido para que la app se vea bien
 * tanto en móvil como en web de escritorio.
 */
export const breakpoints = {
  /** Tablets y ventanas medianas. */
  tablet: 768,
  /** Escritorio: activa top-nav y layouts de dos columnas. */
  desktop: 1024
};

export const contentWidth = {
  /** Formularios y flujos enfocados (login, onboarding). */
  narrow: 480,
  /** Feeds de una columna (matches, perfil). */
  base: 640,
  /** Layouts de dos columnas (discover en desktop). Medida premium: el
      contenido respira y no se estira en monitores anchos. */
  wide: 1240
};

/**
 * Dimensiones del tab bar flotante (móvil).
 * El pill tiene 68 px; la pelota central sobresale ~23 px por encima.
 * El padding inferior real = max(10, insets.bottom).
 */
export const mobileTabBar = {
  pillHeight: 68,
  ballSize: 88,
  /** Margen mínimo bajo el pill (gestos / home indicator). */
  minBottomPad: 10,
  /**
   * Espacio libre por encima del pill (pelota + aire) para que CTAs
   * como «Cómo llegar» y «Perfil» no queden bajo el menú.
   */
  contentClearance: 96
} as const;

export type Breakpoint = "compact" | "tablet" | "desktop";

/**
 * Breakpoint reactivo al tamaño de la ventana (funciona en web al
 * redimensionar y en dispositivos al rotar).
 */
export function useBreakpoint() {
  const { width } = useWindowDimensions();
  const breakpoint: Breakpoint =
    width >= breakpoints.desktop ? "desktop" : width >= breakpoints.tablet ? "tablet" : "compact";
  return {
    breakpoint,
    width,
    isCompact: breakpoint === "compact",
    isDesktop: breakpoint === "desktop",
    /** Tablet o superior. */
    isWide: breakpoint !== "compact"
  };
}

/**
 * Padding inferior de scroll en pantallas con tab bar flotante.
 * Usa insets reales (modo gesto, Huawei, etc.) en lugar de un valor fijo.
 */
export function useTabBarScrollPadding(extra = 0) {
  const insets = useSafeAreaInsets();
  const { isWide } = useBreakpoint();
  if (isWide) return Math.max(32, extra);
  const bottomPad = Math.max(mobileTabBar.minBottomPad, insets.bottom);
  return bottomPad + mobileTabBar.pillHeight + mobileTabBar.contentClearance + extra;
}

/**
 * Insets de safe area listos para headers custom y pantallas sin Stack header.
 */
export function useScreenSafePadding() {
  const insets = useSafeAreaInsets();
  return {
    top: statusBarTopInset(insets.top),
    bottom: Math.max(insets.bottom, 0),
    left: Math.max(insets.left, 0),
    right: Math.max(insets.right, 0)
  };
}
