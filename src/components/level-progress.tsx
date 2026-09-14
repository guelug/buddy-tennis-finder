import * as React from "react";
import { Text, View } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withDelay, withTiming } from "react-native-reanimated";
import { Icon } from "@/components/icon";
import { CountUp } from "@/components/count-up";
import { useI18n } from "@/lib/i18n";
import { TIER_META } from "@/data/rankings";
import type { LevelProgress as Level } from "@/lib/gamification";
import { broadcast, colors, radii, spacing, typography } from "@/theme";

/**
 * Nivel del jugador y barra hacia el siguiente. El rango reutiliza los colores
 * de tier del ranking para que "oro" signifique lo mismo en toda la app.
 */
export function LevelProgress({ level, compact = false }: { level: Level; compact?: boolean }) {
  const { t } = useI18n();
  const tier = TIER_META[level.tier];
  const width = useSharedValue(0);

  React.useEffect(() => {
    width.value = withDelay(220, withTiming(level.progress, { duration: 800 }));
  }, [level.progress, width]);

  const fillStyle = useAnimatedStyle(() => ({ width: `${Math.round(width.value * 100)}%` }));

  return (
    <View style={{ gap: spacing.sm }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
        {/* El color del rango vive en el borde, no en el número: los tonos de
            tier (plata, bronce) no llegan a AA como tinta sobre superficie. */}
        <View
          style={{
            alignItems: "center",
            backgroundColor: colors.surfaceCourt,
            borderColor: tier.color,
            borderRadius: radii.md,
            borderWidth: 2,
            height: compact ? 44 : 54,
            justifyContent: "center",
            width: compact ? 44 : 54
          }}
        >
          <Text style={{ ...broadcast.stat, color: colors.textPrimary, fontSize: compact ? 20 : 25 }}>
            {level.level}
          </Text>
        </View>
        <View style={{ flex: 1, gap: 2 }}>
          <Text style={{ ...broadcast.jersey, color: colors.textSecondary, fontSize: 10, letterSpacing: 1.4 }}>
            {t("progress.level.kicker")}
          </Text>
          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
            <View style={{ backgroundColor: tier.color, borderRadius: 999, height: 8, width: 8 }} />
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>
              {t(`progress.tier.${level.tier}`)}
            </Text>
          </View>
        </View>
        <View style={{ alignItems: "flex-end" }}>
          <CountUp value={level.xp} style={{ ...broadcast.stat, color: colors.textPrimary, fontSize: compact ? 19 : 23 }} />
          <Text style={{ ...typography.footnote, color: colors.textTertiary, fontSize: 10 }}>
            {t("progress.level.points")}
          </Text>
        </View>
      </View>

      <View
        style={{
          backgroundColor: colors.surfaceCourt,
          borderColor: colors.border,
          borderRadius: radii.pill,
          borderWidth: 1,
          height: 10,
          overflow: "hidden"
        }}
      >
        <Animated.View
          style={[
            { backgroundColor: colors.accentFill, borderRadius: radii.pill, height: "100%" },
            fillStyle
          ]}
        />
      </View>

      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
        {level.maxed
          ? t("progress.level.maxed")
          : t("progress.level.toNext")
              .replace("{points}", String(level.xpForNextLevel - level.xpIntoLevel))
              .replace("{level}", String(level.level + 1))}
      </Text>
    </View>
  );
}

/** Racha de constancia semanal — el dato que más mueve a volver a la pista. */
export function StreakPill({ weeks }: { weeks: number }) {
  const { t } = useI18n();
  if (weeks <= 0) return null;
  return (
    <View
      style={{
        alignItems: "center",
        alignSelf: "flex-start",
        backgroundColor: colors.goldSoft,
        borderColor: `${colors.goldFill}55`,
        borderRadius: radii.pill,
        borderWidth: 1,
        flexDirection: "row",
        gap: spacing.xs,
        paddingHorizontal: spacing.md,
        paddingVertical: 5
      }}
    >
      <Icon name="zap" size={12} color={colors.goldFill as string} />
      <Text style={{ ...typography.footnote, color: colors.gold, fontWeight: "800" }}>
        {t("progress.streak.weeks").replace("{count}", String(weeks))}
      </Text>
    </View>
  );
}
