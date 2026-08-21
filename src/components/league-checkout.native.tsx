import { useEffect, useRef, useState } from "react";
import { Alert, Platform, Text, View } from "react-native";
import { Icon } from "@/components/icon";
import { PrimaryButton } from "@/components/primary-button";
import { usePurchases } from "@/components/purchase-provider";
import { PRIVATE_LEAGUE_PRODUCT } from "@/lib/community";
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography } from "@/theme";
import type { PrivateLeagueInput } from "@/types";

export function LeagueCheckout({ input, onCreated }: { input: PrivateLeagueInput; onCreated: (leagueId: string) => void }) {
  const [processing, setProcessing] = useState(false);
  const [attemptId, setAttemptId] = useState<number | null>(null);
  const handledOutcome = useRef(0);
  const { connected, products, outcome, startLeaguePurchase } = usePurchases();
  const { t } = useI18n();
  const storeName = Platform.OS === "ios" ? "App Store" : "Google Play";
  useEffect(() => {
    if (!outcome || outcome.kind !== "league" || outcome.intentCreatedAt !== attemptId || handledOutcome.current === outcome.occurredAt) return;
    handledOutcome.current = outcome.occurredAt;
    if (outcome.status === "recovering") {
      setProcessing(true);
      return;
    }
    setProcessing(false);
    if (outcome.status === "verified" && outcome.leagueId) {
      Alert.alert(t("leagueCheckout.createdTitle"), t("leagueCheckout.createdBody"));
      onCreated(outcome.leagueId);
    } else if (outcome.status !== "cancelled") {
      Alert.alert(t("leagueCheckout.pendingTitle"), outcome.message || t("leagueCheckout.pendingBody"));
    }
  }, [outcome, attemptId, onCreated, t]);
  const product = products.find((item) => item.id === PRIVATE_LEAGUE_PRODUCT.id);
  const price = product?.displayPrice ?? PRIVATE_LEAGUE_PRODUCT.fallbackPrice;
  const buy = async () => {
    setProcessing(true);
    try {
      if (!connected) throw new Error(t("leagueCheckout.unavailable").replace("{store}", storeName));
      setAttemptId(await startLeaguePurchase(input));
    } catch (error) {
      setProcessing(false);
      Alert.alert(
        t("leagueCheckout.cantOpen").replace("{store}", storeName),
        error instanceof Error ? error.message : t("leagueCheckout.retry")
      );
    }
  };
  return <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.lg, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}><View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}><Icon name="trophy" size={24} color={colors.neon as string} /><View style={{ flex: 1 }}><Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("leagueCheckout.title")}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("leagueCheckout.subtitle")}</Text></View><Text style={{ ...typography.headline, color: colors.neon }}>{price}</Text></View><PrimaryButton label={processing ? t("leagueCheckout.verifying") : t("leagueCheckout.buy")} disabled={processing} onPress={() => void buy()} /></View>;
}
