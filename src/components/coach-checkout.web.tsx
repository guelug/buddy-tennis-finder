import { Text, View } from "react-native";
import { Icon } from "@/components/icon";
import { COACH_PRODUCTS } from "@/lib/community";
import { colors, radii, spacing, typography } from "@/theme";
import type { CoachAd } from "@/types";

export function CoachCheckout({ ad }: { ad: CoachAd; onActivated: () => void }) {
  return (
    <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.lg, borderWidth: 1, flexDirection: "row", gap: spacing.md, padding: spacing.lg }}>
      <Icon name="check-badge" size={22} color={colors.neon as string} />
      <View style={{ flex: 1 }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>Termina la publicación desde Android</Text>
        <Text style={{ ...typography.body, color: colors.textSecondary }}>
          El borrador está guardado. Abre MatchPoint Tennis en Android para pagar {COACH_PRODUCTS[ad.plan].fallbackPrice} mediante Google Play y activar el anuncio.
        </Text>
      </View>
    </View>
  );
}
