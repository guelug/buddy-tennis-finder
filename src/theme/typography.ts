import type { TextStyle as RNTextStyle } from "react-native";

/**
 * Sistema tipográfico MatchPoint Tennis — legible y premium.
 *
 * DUAL SYSTEM:
 *  - **Body / UI**: Inter (web) / SF Pro (iOS) / Roboto (Android). Fallback
 *    system fonts. Perfecto para lectura prolongada.
 *  - **Display / Broadcast**: "Saira Condensed" — para scores, rankings y
 *    títulos hero. Cargada vía expo-font.
 *
 * Principios:
 *  - Body 16/24 para legibilidad.
 *  - Contraste alto pero no agresivo.
 *  - Espaciado entre líneas generoso.
 *  - Pesos claros: 400/500/600 para UI, 700/800/900 para display.
 */

export type TextStyle = Pick<
  RNTextStyle,
  "fontSize" | "fontWeight" | "lineHeight" | "letterSpacing" | "fontFamily"
>;

export const BROADCAST_FONT = "SairaCondensed";
export const BROADCAST_FONTS = {
  semiBold: "SairaCondensed-SemiBold",
  extraBold: "SairaCondensed-ExtraBold",
  black: "SairaCondensed-Black"
} as const;

export const typography = {
  /** Título de pantalla grande. */
  largeTitle: {
    fontSize: 34,
    fontWeight: "700",
    lineHeight: 40,
    letterSpacing: -0.3
  } satisfies TextStyle,

  /** Título principal de sección. */
  title: {
    fontSize: 28,
    fontWeight: "700",
    lineHeight: 34,
    letterSpacing: -0.2
  } satisfies TextStyle,

  /** Título de card o bloque. */
  headline: {
    fontSize: 20,
    fontWeight: "600",
    lineHeight: 26,
    letterSpacing: -0.1
  } satisfies TextStyle,

  /** Subtítulo o nombre de jugador. */
  subheadline: {
    fontSize: 17,
    fontWeight: "600",
    lineHeight: 22,
    letterSpacing: 0
  } satisfies TextStyle,

  /** Texto de cuerpo principal — legible y aireado. */
  body: {
    fontSize: 16,
    fontWeight: "400",
    lineHeight: 24,
    letterSpacing: -0.15
  } satisfies TextStyle,

  /** Texto de cuerpo enfatizado. */
  bodyEmphasized: {
    fontSize: 16,
    fontWeight: "600",
    lineHeight: 24,
    letterSpacing: -0.1
  } satisfies TextStyle,

  /** Texto pequeño / metadata. */
  caption: {
    fontSize: 14,
    fontWeight: "500",
    lineHeight: 18,
    letterSpacing: 0.05
  } satisfies TextStyle,

  /** Pie / disclaimer. */
  footnote: {
    fontSize: 13,
    fontWeight: "400",
    lineHeight: 17,
    letterSpacing: 0.05
  } satisfies TextStyle,

  /** Métricas y contadores UI. */
  metric: {
    fontSize: 26,
    fontWeight: "800",
    lineHeight: 30,
    letterSpacing: -0.3
  } satisfies TextStyle
};

export const broadcast = {
  scoreboard: {
    fontFamily: BROADCAST_FONTS.black,
    fontSize: 44,
    fontWeight: "900",
    lineHeight: 48,
    letterSpacing: 0
  } satisfies TextStyle,

  rank: {
    fontFamily: BROADCAST_FONTS.extraBold,
    fontSize: 36,
    fontWeight: "800",
    lineHeight: 40,
    letterSpacing: 0.2
  } satisfies TextStyle,

  hero: {
    fontFamily: BROADCAST_FONTS.extraBold,
    fontSize: 32,
    fontWeight: "800",
    lineHeight: 36,
    letterSpacing: 0.3
  } satisfies TextStyle,

  jersey: {
    fontFamily: BROADCAST_FONTS.semiBold,
    fontSize: 13,
    fontWeight: "600",
    lineHeight: 15,
    letterSpacing: 1.4
  } satisfies TextStyle,

  stat: {
    fontFamily: BROADCAST_FONTS.extraBold,
    fontSize: 22,
    fontWeight: "800",
    lineHeight: 25,
    letterSpacing: 0.2
  } satisfies TextStyle
};

export default typography;
