import * as React from "react";
import { Text, View } from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";
import { TennisBall } from "@/components/tennis-ball";
import { CourtLines } from "@/components/court-lines";
import { colors, radii, spacing, typography, shadows } from "@/theme";

type HeroBannerProps = {
  eyebrow?: string;
  title: string;
  highlight?: string;
  subtitle?: string;
  children?: React.ReactNode;
};

/**
 * Hero dramático inspirado en Betguate — gradiente verde + acento oro + decoración tennis.
 * Usar en web y en pantallas destacadas (Liga, Rivales).
 */
export function HeroBanner({ eyebrow, title, highlight, subtitle, children }: HeroBannerProps) {
  return (
    <Animated.View entering={FadeIn.springify().damping(18)}>
      <View
        style={{
          backgroundColor: colors.courtDeep,
          borderColor: "rgba(198,241,53,0.13)",
          borderWidth: 1,
          borderCurve: "continuous",
          borderRadius: radii.xl,
          boxShadow: shadows.floating,
          overflow: "hidden",
          padding: spacing.xl,
          position: "relative"
        }}
      >
        <CourtLines color="rgba(198,241,53,0.10)" />

        {/* Capas de profundidad con gradientes sutiles */}
        <View
          style={{
            backgroundColor: "rgba(255,255,255,0.06)",
            borderRadius: radii.pill,
            height: 180,
            position: "absolute",
            right: -40,
            top: -60,
            width: 180
          }}
        />
        <View
          style={{
            backgroundColor: "rgba(198,241,53,0.10)",
            borderRadius: radii.pill,
            bottom: -30,
            height: 120,
            left: -20,
            position: "absolute",
            width: 120
          }}
        />

        <Animated.View
          entering={FadeIn.delay(180).springify()}
          style={{ position: "absolute", right: spacing.lg, top: spacing.lg }}
        >
          <TennisBall size={64} />
        </Animated.View>

        <View style={{ gap: spacing.sm, zIndex: 1, maxWidth: "82%" }}>
          {eyebrow ? (
            <Text
              style={{
                ...typography.caption,
                color: "rgba(255,255,255,0.75)",
                fontSize: 11,
                letterSpacing: 1.6,
                textTransform: "uppercase"
              }}
            >
              {eyebrow}
            </Text>
          ) : null}
          <Text style={{ ...typography.title, color: "#fff", fontSize: 28, lineHeight: 32 }}>
            {title}
            {highlight ? (
              <Text style={{ color: "#C6F135" }}> {highlight}</Text>
            ) : null}
          </Text>
          {subtitle ? (
            <Text style={{ ...typography.body, color: "rgba(255,255,255,0.82)", fontSize: 15, lineHeight: 22 }}>
              {subtitle}
            </Text>
          ) : null}
          {children}
        </View>
      </View>
    </Animated.View>
  );
}
