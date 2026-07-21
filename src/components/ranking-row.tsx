import { Text, View } from "react-native";
import Animated, { FadeInRight } from "react-native-reanimated";
import { Avatar } from "@/components/avatar";
import { RankBadge } from "@/components/rank-badge";
import { TIER_META } from "@/data/rankings";
import { RankingEntry } from "@/types";
import { colors, radii, shadows, spacing, typography } from "@/theme";

type RankingRowProps = {
  entry: RankingEntry;
  highlight?: boolean;
  index?: number;
};

export function RankingRow({ entry, highlight = false, index = 0 }: RankingRowProps) {
  const tierColor = TIER_META[entry.tier].color;

  return (
    <Animated.View entering={FadeInRight.delay(index * 40).springify().damping(18)}>
      <View
        style={{
          alignItems: "center",
          backgroundColor: highlight ? colors.goldSoft : colors.surface,
          borderBottomColor: colors.border,
          borderBottomWidth: 1,
          flexDirection: "row",
          gap: spacing.md,
          paddingHorizontal: spacing.base,
          paddingVertical: spacing.md,
          boxShadow: highlight ? shadows.glowGold : undefined
        }}
      >
        <Text
          style={{
            ...typography.subheadline,
            color: entry.rank <= 3 ? tierColor : colors.textSecondary,
            fontVariant: ["tabular-nums"],
            fontWeight: "900",
            textAlign: "center",
            width: 28
          }}
        >
          {entry.rank}
        </Text>
        <Avatar name={entry.playerName} size={36} />
        <View style={{ flex: 1, gap: 2 }}>
          <Text style={{ ...typography.bodyEmphasized, color: colors.textPrimary }} numberOfLines={1}>
            {entry.playerName}
            {highlight ? " (tú)" : ""}
          </Text>
          <Text style={{ ...typography.footnote, color: colors.textTertiary }}>
            {entry.wins}W · {entry.losses}L · racha {entry.streak}
          </Text>
        </View>
        <View style={{ alignItems: "flex-end", gap: 4 }}>
          <RankBadge tier={entry.tier} />
          <Text style={{ ...typography.caption, color: colors.court, fontWeight: "800", fontVariant: ["tabular-nums"] }}>
            {entry.points} pts
          </Text>
        </View>
      </View>
    </Animated.View>
  );
}