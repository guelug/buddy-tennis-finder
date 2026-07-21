import { Text, View } from "react-native";
import { TIER_META } from "@/data/rankings";
import { RankTier } from "@/types";
import { radii, typography } from "@/theme";

type RankBadgeProps = {
  tier: RankTier;
  size?: "sm" | "md";
};

export function RankBadge({ tier, size = "sm" }: RankBadgeProps) {
  const meta = TIER_META[tier];
  const isMd = size === "md";

  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: `${meta.color}18`,
        borderColor: `${meta.color}55`,
        borderCurve: "continuous",
        borderRadius: radii.pill,
        borderWidth: 1,
        flexDirection: "row",
        gap: 4,
        paddingHorizontal: isMd ? 10 : 8,
        paddingVertical: isMd ? 5 : 3
      }}
    >
      <Text style={{ color: meta.color, fontSize: isMd ? 12 : 10 }}>{meta.icon}</Text>
      <Text
        style={{
          ...typography.caption,
          color: meta.color,
          fontSize: isMd ? 12 : 10,
          fontWeight: "800",
          letterSpacing: 0.8,
          textTransform: "uppercase"
        }}
      >
        {meta.label}
      </Text>
    </View>
  );
}