import { Text, View } from "react-native";
import Animated, { FadeInUp, ZoomIn } from "react-native-reanimated";
import { Avatar } from "@/components/avatar";
import { RankBadge } from "@/components/rank-badge";
import { CountUp } from "@/components/count-up";
import { RankingEntry } from "@/types";
import { colors, radii, spacing, typography, shadows } from "@/theme";

type PodiumProps = {
  entries: RankingEntry[];
};

/** Podio top 3 estilo Betguate — animado, con oro en el #1. */
export function Podium({ entries }: PodiumProps) {
  const first = entries[0];
  const second = entries[1];
  const third = entries[2];

  return (
    <View style={{ alignItems: "flex-end", flexDirection: "row", gap: spacing.sm, justifyContent: "center" }}>
      <PodiumCard entry={second} place={2} delay={120} />
      <PodiumCard entry={first} place={1} delay={0} tall />
      <PodiumCard entry={third} place={3} delay={200} />
    </View>
  );
}

function PodiumCard({
  entry,
  place,
  delay,
  tall = false
}: {
  entry?: RankingEntry;
  place: 1 | 2 | 3;
  delay: number;
  tall?: boolean;
}) {
  const placeColor = place === 1 ? colors.gold : place === 2 ? "#8A9BA8" : "#B87333";
  const height = tall ? 200 : place === 2 ? 160 : 140;

  if (!entry) {
    return (
      <View
        style={{
          alignItems: "center",
          backgroundColor: colors.surface,
          borderColor: colors.border,
          borderRadius: radii.lg,
          borderWidth: 1,
          flex: 1,
          height,
          justifyContent: "center",
          maxWidth: 120,
          opacity: 0.5
        }}
      >
        <Text style={{ ...typography.caption, color: colors.textTertiary }}>#{place}</Text>
      </View>
    );
  }

  return (
    <Animated.View
      entering={FadeInUp.delay(delay).springify().damping(16)}
      style={{
        alignItems: "center",
        backgroundColor: colors.surface,
        borderColor: place === 1 ? `${colors.gold}66` : colors.border,
        borderCurve: "continuous",
        borderRadius: radii.lg,
        borderWidth: place === 1 ? 2 : 1,
        boxShadow: place === 1 ? shadows.floating : shadows.card,
        flex: 1,
        gap: spacing.sm,
        height,
        justifyContent: "flex-end",
        maxWidth: tall ? 140 : 120,
        padding: spacing.md,
        paddingBottom: spacing.base
      }}
    >
      <Animated.View entering={ZoomIn.delay(delay + 80).springify()}>
        <View
          style={{
            alignItems: "center",
            backgroundColor: placeColor,
            borderRadius: radii.pill,
            height: 28,
            justifyContent: "center",
            width: 28,
            boxShadow: place === 1 ? "0 4px 12px -2px rgba(224,169,52,0.45)" : undefined
          }}
        >
          <Text style={{ color: place === 1 ? "#231800" : "#fff", fontSize: 13, fontWeight: "900" }}>
            {place === 1 ? "👑" : place}
          </Text>
        </View>
      </Animated.View>
      <Avatar name={entry.playerName} size={tall ? 52 : 44} />
      <Text
        style={{ ...typography.caption, color: colors.textPrimary, fontSize: 12, fontWeight: "700", textAlign: "center" }}
        numberOfLines={1}
      >
        {entry.playerName.split(" ")[0]}
      </Text>
      <RankBadge tier={entry.tier} />
      <CountUp
        value={entry.points}
        style={{ ...typography.metric, color: colors.court, fontSize: tall ? 20 : 16, fontVariant: ["tabular-nums"] }}
      />
    </Animated.View>
  );
}