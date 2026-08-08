import { Text, View } from "react-native";
import { Icon } from "@/components/icon";
import { PRIVATE_LEAGUE_PRODUCT } from "@/lib/community";
import { colors, radii, spacing, typography } from "@/theme";
import type { PrivateLeagueInput } from "@/types";

export function LeagueCheckout({ input }: { input: PrivateLeagueInput; onCreated: (leagueId: string) => void }) {
  return <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.lg, borderWidth: 1, flexDirection: "row", gap: spacing.md, padding: spacing.lg }}><Icon name="trophy" size={24} color={colors.neon as string} /><View style={{ flex: 1 }}><Text style={{ ...typography.subheadline, color: colors.textPrimary }}>Crea {input.name} desde Android</Text><Text style={{ ...typography.body, color: colors.textSecondary }}>Por seguridad, las ligas de pago se crean en MP Tennis League App para Android mediante Google Play ({PRIVATE_LEAGUE_PRODUCT.fallbackPrice}). Abre la app y completa allí estos datos.</Text></View></View>;
}
