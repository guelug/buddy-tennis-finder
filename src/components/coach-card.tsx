import { Pressable, Text, View } from "react-native";
import { router } from "expo-router";
import { Avatar } from "@/components/avatar";
import { Chip } from "@/components/chip";
import { Icon } from "@/components/icon";
import { colors, radii, shadows, spacing, typography } from "@/theme";
import type { CoachAd } from "@/types";

export function CoachCard({ ad, compact = false }: { ad: CoachAd; compact?: boolean }) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`Ver entrenador ${ad.coachName}`}
      onPress={() => router.push({ pathname: "/coach/[id]", params: { id: ad.id } } as never)}
      style={({ pressed }) => ({
        backgroundColor: pressed ? colors.courtLight : colors.surface,
        borderColor: `${colors.neon}3A`,
        borderCurve: "continuous",
        borderRadius: radii.xl,
        borderWidth: 1,
        boxShadow: shadows.card,
        flexBasis: compact ? 260 : 320,
        flexGrow: 1,
        gap: spacing.md,
        minWidth: compact ? 240 : 280,
        opacity: pressed ? 0.92 : 1,
        padding: spacing.lg
      })}
    >
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
        <Avatar name={ad.coachName} photoURL={ad.photoURL} size={compact ? 54 : 64} />
        <View style={{ flex: 1, gap: 2 }}>
          <View style={{ alignItems: "center", flexDirection: "row", gap: 6 }}>
            <Text numberOfLines={1} style={{ ...typography.headline, color: colors.textPrimary, flex: 1 }}>{ad.coachName}</Text>
            <Icon name="check-badge" size={17} color={colors.neon as string} />
          </View>
          <View style={{ alignItems: "center", flexDirection: "row", gap: 5 }}>
            <Icon name="map-pin" size={13} color={colors.textTertiary as string} />
            <Text numberOfLines={1} style={{ ...typography.footnote, color: colors.textSecondary }}>{ad.city || "Entrenamiento flexible"}</Text>
          </View>
        </View>
      </View>
      <View style={{ gap: 5 }}>
        <Text numberOfLines={2} style={{ ...typography.subheadline, color: colors.neon }}>{ad.headline}</Text>
        <Text numberOfLines={compact ? 2 : 3} style={{ ...typography.body, color: colors.textSecondary }}>{ad.bio}</Text>
      </View>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
        {ad.specialties.slice(0, 3).map((item) => <Chip key={item} label={item} />)}
      </View>
      <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
        <Text style={{ ...typography.caption, color: colors.gold }}>{ad.priceNote || "Consulta disponibilidad"}</Text>
        <View style={{ alignItems: "center", flexDirection: "row", gap: 4 }}>
          <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "900" }}>VER PERFIL</Text>
          <Icon name="chevron-right" size={15} color={colors.neon as string} />
        </View>
      </View>
    </Pressable>
  );
}
