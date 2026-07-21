import { Text, View } from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";
import { Card } from "@/components/card";
import { Avatar } from "@/components/avatar";
import { Icon } from "@/components/icon";
import { PlayedMatch } from "@/types";
import { colors, radii, spacing, typography } from "@/theme";

type PlayedMatchCardProps = {
  match: PlayedMatch;
  currentPlayerId?: string;
  clubName?: string;
  index?: number;
};

export function PlayedMatchCard({ match, currentPlayerId, clubName, index = 0 }: PlayedMatchCardProps) {
  const youWon = match.winnerId === currentPlayerId;
  const opponentName =
    match.playerAId === currentPlayerId ? match.playerBName : match.playerAName;

  return (
    <Animated.View entering={FadeIn.delay(index * 50).springify()}>
      <Card
        variant="elevated"
        style={{
          borderColor: youWon ? `${colors.court}33` : colors.border
        }}
      >
        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
          <Avatar name={opponentName} size={44} />
          <View style={{ flex: 1, gap: 2 }}>
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{opponentName}</Text>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
              {clubName ?? "Club"} · {match.format}
            </Text>
          </View>
          <View
            style={{
              alignItems: "center",
              backgroundColor: youWon ? colors.successBg : colors.dangerBg,
              borderRadius: radii.pill,
              flexDirection: "row",
              gap: 4,
              paddingHorizontal: spacing.sm,
              paddingVertical: 4
            }}
          >
            <Icon
              name={youWon ? "trophy" : "sign-out"}
              size={12}
              color={(youWon ? colors.court : colors.danger) as string}
            />
            <Text
              style={{
                ...typography.footnote,
                color: youWon ? colors.court : colors.danger,
                fontWeight: "800"
              }}
            >
              {youWon ? "Victoria" : "Derrota"}
            </Text>
          </View>
        </View>
        <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
          <Text style={{ ...typography.metric, color: colors.textPrimary, fontSize: 18 }}>{match.score}</Text>
          <Text style={{ ...typography.footnote, color: colors.textTertiary }}>
            {new Date(match.playedAt).toLocaleDateString("es-GT", {
              day: "numeric",
              month: "short",
              year: "numeric"
            })}
          </Text>
        </View>
      </Card>
    </Animated.View>
  );
}
