/**
 * MatchPoint Tennis — Sistema de diseño "Night Session" pulido.
 *
 * Dirección: premium, legible y limpio. Fondo oscuro profundo con acento
 * lima neón luminoso. Modo claro cálido y aireado. Tipografía legible,
 * glassmorphism refinado, y sombras que aportan profundidad sin ensuciar.
 */

// ---------------------------------------------------------------------------
// Colores de marca
// ---------------------------------------------------------------------------
export const brand = {
  /** Lima neón luminoso — acento principal. */
  neon: "#C6F135",
  /** Núcleo más brillante del neón para glows. */
  neonBright: "#DBFF63",
  /** Verde cancha profundo. */
  court: "#0E3D24",
  /** Verde cancha más brillante para hover/gradientes. */
  courtBright: "#17663B",
  /** Verde hierba. */
  grass: "#124A2C",
  /** Alias del neón. */
  ball: "#C6F135",
  /** Neón atenuado. */
  ballDim: "#A6D42B",
  /** Rojo coral — errores. */
  clay: "#FF6B5A",
  /** Azul eléctrico — info/links. */
  hardCourt: "#4AA3FF",
  /** Blanco línea de cancha. */
  courtLine: "#FFFFFF",
  /** Oro para rankings. */
  gold: "#F5C542",
  /** Plata para #2. */
  silver: "#C7CDD3",
  /** Bronce para #3. */
  bronze: "#CB8B4E"
};

// ---------------------------------------------------------------------------
// Paleta oscura pulida — contraste alto, superficies refinadas
// ---------------------------------------------------------------------------
export const colors = {
  // Texto
  textPrimary: "#F3F7EF",
  textSecondary: "#A8B8AC",
  textTertiary: "#6B7F70",
  textOnCourt: "#FFFFFF",
  textOnBall: "#08130A",

  // Fondos — negro verdusco, no puro. Más cálido y premium.
  background: "#090E0A",
  backgroundDeep: "#060906",
  surface: "#111A13",
  surfaceElevated: "#19231B",
  surfaceCourt: "#0D140F",

  // Bordes — finos, luminosos, no agresivos
  border: "rgba(234,243,228,0.10)",
  borderStrong: "rgba(234,243,228,0.18)",
  courtLine: "rgba(234,243,228,0.12)",

  // Estado semántico
  success: "#7BE03A",
  successBg: "rgba(123,224,58,0.14)",
  warning: "#F5B841",
  warningBg: "rgba(245,184,65,0.16)",
  danger: brand.clay,
  dangerBg: "rgba(255,107,90,0.16)",
  info: brand.hardCourt,
  infoBg: "rgba(74,163,255,0.16)",

  // Spotlight
  spotlight: brand.neon,
  spotlightDim: brand.ballDim,

  // Marca directa
  court: brand.neon,
  courtDeep: brand.court,
  courtBright: brand.neonBright,
  grass: brand.grass,
  neon: brand.neon,
  ball: brand.ball,
  clay: brand.clay,
  hardCourt: brand.hardCourt,
  gold: brand.gold,
  goldSoft: "rgba(245,197,66,0.16)",
  silver: brand.silver,
  bronze: brand.bronze,

  courtLight: "rgba(198,241,53,0.12)",
  textOnBrand: "#08130A"
};

export type ThemeColorMode = "dark" | "light";

const darkColors = { ...colors };
const lightColors: typeof colors = {
  ...darkColors,
  textPrimary: "#0D1710",
  textSecondary: "#35453A",
  textTertiary: "#4F6255",
  textOnCourt: "#FFFFFF",
  textOnBall: "#FFFFFF",
  textOnBrand: "#FFFFFF",
  background: "#F5F8F1",
  backgroundDeep: "#EBF2E5",
  surface: "#FFFFFF",
  surfaceElevated: "#F3F6EE",
  surfaceCourt: "#EEF3E7",
  border: "rgba(27,55,36,0.12)",
  borderStrong: "rgba(27,55,36,0.24)",
  courtLine: "rgba(27,55,36,0.16)",
  success: "#35781B",
  successBg: "rgba(53,120,27,0.12)",
  warning: "#8A5A00",
  warningBg: "rgba(138,90,0,0.12)",
  danger: "#B23227",
  dangerBg: "rgba(178,50,39,0.10)",
  info: "#0F5E9E",
  infoBg: "rgba(15,94,158,0.10)",
  court: "#4A6E00",
  courtBright: "#5C8600",
  neon: "#4A6E00",
  ball: "#6A9600",
  spotlight: "#4A6E00",
  spotlightDim: "#3F5F00",
  gold: "#8A5D00",
  goldSoft: "rgba(138,93,0,0.12)",
  courtLight: "rgba(74,110,0,0.12)"
};

// ---------------------------------------------------------------------------
// Sombras — suaves, profundas y limpias
// ---------------------------------------------------------------------------
const darkShadows = {
  subtle: "0 1px 2px rgba(0,0,0,0.35)",
  card: "0 8px 24px rgba(0,0,0,0.35), 0 2px 6px rgba(0,0,0,0.22)",
  floating: "0 22px 56px rgba(0,0,0,0.50), 0 8px 16px rgba(0,0,0,0.30)",
  spotlightGlow: "0 0 0 1px rgba(198,241,53,0.50), 0 6px 24px rgba(198,241,53,0.35)",
  courtGlow: "0 0 0 1px rgba(198,241,53,0.22), 0 6px 20px rgba(198,241,53,0.15)",
  glow: "0 0 0 1px rgba(198,241,53,0.50), 0 6px 24px rgba(198,241,53,0.35)",
  glowGold: "0 0 0 1px rgba(245,197,66,0.40), 0 6px 22px rgba(245,197,66,0.22)"
};

const lightShadows: typeof darkShadows = {
  subtle: "0 1px 2px rgba(27,55,36,0.06)",
  card: "0 8px 24px rgba(27,55,36,0.08), 0 2px 6px rgba(27,55,36,0.04)",
  floating: "0 22px 56px rgba(27,55,36,0.12), 0 8px 16px rgba(27,55,36,0.06)",
  spotlightGlow: "0 0 0 1px rgba(82,122,0,0.26), 0 6px 24px rgba(82,122,0,0.14)",
  courtGlow: "0 0 0 1px rgba(82,122,0,0.18), 0 6px 18px rgba(82,122,0,0.10)",
  glow: "0 0 0 1px rgba(82,122,0,0.26), 0 6px 24px rgba(82,122,0,0.14)",
  glowGold: "0 0 0 1px rgba(155,106,0,0.28), 0 6px 22px rgba(155,106,0,0.12)"
};

export const shadows = { ...darkShadows };

export function applyThemeColors(mode: ThemeColorMode) {
  Object.assign(colors, mode === "light" ? lightColors : darkColors);
  Object.assign(shadows, mode === "light" ? lightShadows : darkShadows);
}

// ---------------------------------------------------------------------------
// Radios
// ---------------------------------------------------------------------------
export const radii = {
  xs: 8,
  sm: 12,
  md: 16,
  lg: 20,
  xl: 28,
  pill: 999
};

// ---------------------------------------------------------------------------
// Espaciado
// ---------------------------------------------------------------------------
export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  base: 16,
  lg: 20,
  xl: 24,
  xxl: 32,
  xxxl: 48,
  hero: 64
};

// ---------------------------------------------------------------------------
// Movimiento
// ---------------------------------------------------------------------------
export const motion = {
  fast: 160,
  base: 240,
  slow: 400,
  tap: { damping: 14, stiffness: 380, mass: 0.7 } as const,
  spring: { damping: 16, stiffness: 320, mass: 0.8 } as const,
  enter: { damping: 18, stiffness: 200, mass: 0.9 } as const,
  ballBounce: { damping: 14, stiffness: 280, mass: 1, restitution: 0.53 } as const,
  serve: { damping: 8, stiffness: 220, mass: 1.2 } as const
};

export type ColorToken = keyof typeof colors;
