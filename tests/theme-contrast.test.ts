import assert from "node:assert/strict";
import test from "node:test";
import { applyThemeColors, colors, type ThemeColorMode } from "../src/theme/tokens";

function luminance(hex: string) {
  const channels = hex
    .slice(1)
    .match(/.{2}/g)!
    .map((part) => parseInt(part, 16) / 255)
    .map((value) => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}

function contrast(foreground: string, background: string) {
  const [lighter, darker] = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
  return (lighter + 0.05) / (darker + 0.05);
}

for (const mode of ["dark", "light"] satisfies ThemeColorMode[]) {
  test(`el tema ${mode} mantiene contraste AA en texto y controles`, () => {
    applyThemeColors(mode);
    const pairs = [
      ["texto principal", colors.textPrimary, colors.surface],
      ["texto secundario", colors.textSecondary, colors.surface],
      ["texto terciario", colors.textTertiary, colors.surface],
      ["relleno de acento", colors.onAccentFill, colors.accentFill]
    ] as const;

    for (const [label, foreground, background] of pairs) {
      assert.ok(
        contrast(foreground, background) >= 4.5,
        `${label} no cumple AA en ${mode}: ${foreground} sobre ${background}`
      );
    }
  });
}

/**
 * Los anillos de progreso y las medallas se pintan con rellenos sólidos que son
 * IGUALES en claro y oscuro, con tinta oscura encima. Es lo que permite que un
 * único color funcione en los dos temas; si alguien sustituye uno por un tono
 * más oscuro, el icono de dentro deja de leerse y esta prueba lo detecta.
 */
test("los rellenos de progreso mantienen contraste con su tinta en ambos temas", () => {
  const fills = [
    ["anillo de juego", colors.accentFill],
    ["anillo de competición", colors.clay],
    ["anillo de comunidad", colors.goldFill],
    ["medalla de bronce", "#B87333"],
    ["medalla de plata", "#9BAAB6"],
    ["medalla de oro", "#E0A934"]
  ] as const;

  for (const mode of ["dark", "light"] satisfies ThemeColorMode[]) {
    applyThemeColors(mode);
    for (const [label, fill] of fills) {
      assert.ok(
        contrast(colors.onAccentFill, fill) >= 4.5,
        `${label} no cumple AA en ${mode}: ${colors.onAccentFill} sobre ${fill}`
      );
    }
  }
});

test.after(() => applyThemeColors("dark"));
