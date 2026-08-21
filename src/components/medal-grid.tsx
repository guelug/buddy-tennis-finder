import { Text, View } from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";
import Svg, { Circle } from "react-native-svg";
import { Icon, type IconName } from "@/components/icon";
import { useI18n } from "@/lib/i18n";
import type { MedalProgress, MedalTier } from "@/lib/gamification";
import { colors, radii, spacing, typography } from "@/theme";

/**
 * Vitrina de medallas. Cada una muestra su nivel conseguido y, en el aro
 * exterior, cuánto falta para el siguiente: una medalla bloqueada que enseña
 * "2 de 3" invita más que una silueta gris sin información.
 */

const TIER_FILL: Record<MedalTier, string> = {
  bronce: "#B87333",
  plata: "#9BAAB6",
  oro: "#E0A934"
};

export function MedalGrid({ medals, columns = 3 }: { medals: MedalProgress[]; columns?: number }) {
  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md, justifyContent: "space-between" }}>
      {medals.map((medal, index) => (
        <Medal key={medal.id} medal={medal} index={index} basis={`${Math.floor(100 / columns) - 2}%` as const} />
      ))}
    </View>
  );
}

function Medal({ medal, index, basis }: { medal: MedalProgress; index: number; basis: `${number}%` }) {
  const { t } = useI18n();
  const size = 62;
  const radius = size / 2 - 3;
  const circumference = 2 * Math.PI * radius;
  const fill = medal.tier ? TIER_FILL[medal.tier] : colors.surfaceCourt;

  return (
    <Animated.View
      entering={FadeIn.delay(120 + index * 45).springify()}
      style={{ alignItems: "center", flexBasis: basis, gap: spacing.xs }}
    >
      <View style={{ height: size, width: size }}>
        <Svg width={size} height={size}>
          <Circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            stroke={colors.border as string}
            strokeWidth={3}
            fill="none"
          />
          {medal.progress > 0 ? (
            <Circle
              cx={size / 2}
              cy={size / 2}
              r={radius}
              stroke={colors.accentFill as string}
              strokeWidth={3}
              strokeLinecap="round"
              fill="none"
              strokeDasharray={circumference}
              strokeDashoffset={circumference * (1 - medal.progress)}
              transform={`rotate(-90 ${size / 2} ${size / 2})`}
            />
          ) : null}
        </Svg>
        <View style={{ alignItems: "center", inset: 0, justifyContent: "center", position: "absolute" }}>
          <View
            style={{
              alignItems: "center",
              backgroundColor: fill,
              borderColor: medal.unlocked ? "transparent" : colors.border,
              borderRadius: 999,
              borderWidth: 1,
              height: size - 16,
              justifyContent: "center",
              width: size - 16
            }}
          >
            <Icon
              name={medal.icon as IconName}
              size={22}
              color={(medal.unlocked ? colors.onAccentFill : colors.textTertiary) as string}
            />
          </View>
        </View>
      </View>

      <Text
        style={{
          ...typography.footnote,
          color: medal.unlocked ? colors.textPrimary : colors.textTertiary,
          fontSize: 10,
          fontWeight: "700",
          textAlign: "center"
        }}
        numberOfLines={2}
      >
        {t(`progress.medals.${medal.id}`)}
      </Text>
      <Text style={{ ...typography.footnote, color: colors.textTertiary, fontSize: 9 }}>
        {medal.nextThreshold === null
          ? t("progress.medals.complete")
          : `${medal.value} / ${medal.nextThreshold}`}
      </Text>
    </Animated.View>
  );
}

/** Resumen de una línea para el perfil: cuántas medallas y de qué nivel. */
export function MedalSummary({ medals }: { medals: MedalProgress[] }) {
  const { t } = useI18n();
  const unlocked = medals.filter((medal) => medal.unlocked).length;
  const gold = medals.filter((medal) => medal.tier === "oro").length;

  return (
    <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
        {t("progress.medals.summary").replace("{unlocked}", String(unlocked)).replace("{total}", String(medals.length))}
      </Text>
      {gold > 0 ? (
        <View
          style={{
            alignItems: "center",
            backgroundColor: TIER_FILL.oro,
            borderRadius: radii.pill,
            flexDirection: "row",
            gap: 3,
            paddingHorizontal: spacing.sm,
            paddingVertical: 2
          }}
        >
          <Icon name="star" size={10} color={colors.onAccentFill as string} />
          <Text style={{ ...typography.footnote, color: colors.onAccentFill, fontSize: 10, fontWeight: "800" }}>
            {gold}
          </Text>
        </View>
      ) : null}
    </View>
  );
}
