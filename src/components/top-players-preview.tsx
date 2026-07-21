import { Pressable, Text, View } from "react-native";
import { router } from "expo-router";
import Animated, { FadeIn, FadeInRight } from "react-native-reanimated";
import { Card } from "@/components/card";
import { Avatar } from "@/components/avatar";
import { RankBadge } from "@/components/rank-badge";
import { SectionTitle } from "@/components/section-title";
import { TIER_META } from "@/data/rankings";
import { RankingEntry } from "@/types";
import { colors, spacing, typography } from "@/theme";

type TopPlayersPreviewProps = {
  entries: RankingEntry[];
  divisionLabel: string;
};

/** Teaser del ranking — estilo TopPlayers de Betguate. */
export function TopPlayersPreview({ entries, divisionLabel }: TopPlayersPreviewProps) {
  const top = entries.slice(0, 3);

  return (
    <Animated.View entering={FadeIn.delay(120).springify()}>
      <SectionTitle title={`Top ${divisionLabel}`} actionLabel="Ver liga" onAction={() => router.push("/liga")} />
      <Card style={{ overflow: "hidden", padding: 0 }}>
        {top.map((entry, index) => (
          <Animated.View
            key={entry.playerId}
            entering={FadeInRight.delay(80 + index * 60).springify().damping(18)}
          >
            <Pressable
              accessibilityLabel={`Ver perfil de ${entry.playerName}`}
              onPress={() => router.push(`/player/${entry.playerId}` as never)}
              style={{
                alignItems: "center",
                borderBottomColor: colors.border,
                borderBottomWidth: index < top.length - 1 ? 1 : 0,
                flexDirection: "row",
                gap: spacing.md,
                paddingHorizontal: spacing.base,
                paddingVertical: spacing.md
              }}
            >
              <Text
                style={{
                  ...typography.subheadline,
                  color: TIER_META[entry.tier].color,
                  fontWeight: "900",
                  textAlign: "center",
                  width: 24
                }}
              >
                {entry.rank}
              </Text>
              <Avatar name={entry.playerName} size={32} />
              <Text style={{ ...typography.body, color: colors.textPrimary, flex: 1, fontWeight: "600" }} numberOfLines={1}>
                {entry.playerName}
              </Text>
              <RankBadge tier={entry.tier} />
            </Pressable>
          </Animated.View>
        ))}
      </Card>
    </Animated.View>
  );
}
