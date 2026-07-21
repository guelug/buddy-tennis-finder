import * as React from "react";
import { ImageBackground, Text, View } from "react-native";
import Animated, { FadeIn, FadeInUp } from "react-native-reanimated";
import { CourtRally } from "@/components/court-rally";
import { colors, radii, spacing, typography, shadows, useThemeMode } from "@/theme";

const heroCourtDark = require("@/../assets/generated/hero-court-mobile-dark.webp");
const heroCourtLight = require("@/../assets/generated/hero-court-mobile-light.webp");

type ScreenHeroProps = {
  /** Texto corto de contexto (1 línea máx). */
  hint?: string;
  /** Métricas rápidas en la parte inferior del hero. */
  stats?: Array<{ label: string; value: string | number }>;
  /** Margen negativo horizontal para sangrar hasta los bordes del scroll. */
  bleed?: number;
  /** Mostrar el peloteo en pista a la derecha. Default true. */
  rally?: boolean;
};

/**
 * Banda superior con tinte de marca y decoración tennis. Da profundidad visual
 * sin duplicar el large title del navigation header.
 *
 * A la derecha vive el CourtRally: la mini-pista en perspectiva con el peloteo
 * en vivo (reemplaza a la antigua pelotita de lado a lado entre postes).
 */
export function ScreenHero({ hint, stats, bleed = spacing.base, rally = true }: ScreenHeroProps) {
  const { isLight } = useThemeMode();
  const secondary = isLight ? "rgba(16,32,22,.84)" : "rgba(255,255,255,.76)";
  return (
    <Animated.View
      entering={FadeInUp.springify().damping(20)}
      style={{
        backgroundColor: isLight ? "#EEF2E7" : colors.courtDeep,
        borderBottomLeftRadius: radii.xl,
        borderBottomRightRadius: radii.xl,
        borderColor: `${colors.neon}1F`,
        borderWidth: 1,
        borderTopWidth: 0,
        borderCurve: "continuous",
        marginHorizontal: -bleed,
        overflow: "hidden",
        boxShadow: shadows.subtle
      }}
    >
      <ImageBackground
        source={isLight ? heroCourtLight : heroCourtDark}
        resizeMode="cover"
        style={{ paddingBottom: spacing.lg, paddingHorizontal: bleed, paddingTop: spacing.lg }}
      >
      <View pointerEvents="none" style={{ backgroundColor: isLight ? "rgba(244,247,241,.34)" : "rgba(2,7,4,.08)", bottom: 0, left: 0, position: "absolute", right: 0, top: 0 }} />
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md, minHeight: 146 }}>
        {/* Columna de contenido */}
        <View style={{ flex: 1, gap: spacing.md, minWidth: 0 }}>
          {hint ? (
            <Text style={{ ...typography.body, color: secondary, fontSize: 15, lineHeight: 20, maxWidth: 270 }}>
              {hint}
            </Text>
          ) : null}
          {stats && stats.length > 0 ? (
            <View style={{ flexDirection: "row", gap: spacing.sm }}>
              {stats.map((stat, index) => (
                <Animated.View
                  entering={FadeInUp.delay(120 + index * 60).springify().damping(18)}
                  key={stat.label}
                  style={{
                    backgroundColor: isLight ? "rgba(255,255,255,.86)" : "rgba(2,8,5,.68)",
                    borderColor: isLight ? "rgba(68,101,45,.18)" : `${colors.neon}2E`,
                    borderCurve: "continuous",
                    borderRadius: radii.md,
                    borderWidth: 1,
                    flex: 1,
                    gap: 2,
                    paddingHorizontal: spacing.md,
                    paddingVertical: spacing.sm
                  }}
                >
                  <Text
                    style={{
                      ...typography.metric,
                      color: colors.neon,
                      fontSize: 22,
                      fontVariant: ["tabular-nums"]
                    }}
                  >
                    {stat.value}
                  </Text>
                  <Text style={{ ...typography.footnote, color: secondary, fontWeight: "600" }}>
                    {stat.label}
                  </Text>
                </Animated.View>
              ))}
            </View>
          ) : null}
        </View>

        {/* Peloteo en vivo: devuelve la acción y explica visualmente el producto. */}
        {rally ? (
          <Animated.View entering={FadeIn.delay(180).duration(400)} style={{ alignItems: "center", justifyContent: "center", minWidth: 100 }}>
            <View style={{ backgroundColor: isLight ? "rgba(255,255,255,.50)" : "rgba(2,8,5,.44)", borderColor: `${colors.neon}33`, borderRadius: radii.lg, borderWidth: 1, overflow: "hidden" }}>
              <CourtRally size={96} duration={3000} />
            </View>
          </Animated.View>
        ) : null}
      </View>
      </ImageBackground>
    </Animated.View>
  );
}
