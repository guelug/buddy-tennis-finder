import { useEffect, useMemo, useRef, useState } from "react";
import { Alert, Platform, Text, View } from "react-native";
import { Icon } from "@/components/icon";
import { PrimaryButton } from "@/components/primary-button";
import { usePurchases } from "@/components/purchase-provider";
import { COACH_PRODUCTS } from "@/lib/community";
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography } from "@/theme";
import type { CoachAd } from "@/types";

export function CoachCheckout({ ad, onActivated }: { ad: CoachAd; onActivated: () => void }) {
  const [processing, setProcessing] = useState(false);
  const handledOutcome = useRef(0);
  const productId = COACH_PRODUCTS[ad.plan].id;
  const { connected, products, outcome, startCoachPurchase } = usePurchases();
  const { t } = useI18n();
  const storeName = Platform.OS === "ios" ? "App Store" : "Google Play";

  useEffect(() => {
    if (!outcome || outcome.kind !== "coach" || outcome.adId !== ad.id || handledOutcome.current === outcome.occurredAt) return;
    handledOutcome.current = outcome.occurredAt;
    if (outcome.status === "recovering") {
      setProcessing(true);
      return;
    }
    setProcessing(false);
    if (outcome.status === "verified") {
      Alert.alert(
        t("coachCheckout.publishedTitle"),
        t("coachCheckout.publishedBody").replace("{days}", String(COACH_PRODUCTS[ad.plan].days))
      );
      onActivated();
    } else if (outcome.status !== "cancelled") {
      Alert.alert(t("coachCheckout.pendingTitle"), outcome.message || t("coachCheckout.pendingBody"));
    }
  }, [outcome, ad.id, ad.plan, onActivated, t]);

  const product = useMemo(() => products.find((item) => item.id === productId), [productId, products]);
  const price = product?.displayPrice ?? COACH_PRODUCTS[ad.plan].fallbackPrice;

  const buy = async () => {
    setProcessing(true);
    try {
      if (!connected) throw new Error(t("coachCheckout.unavailable").replace("{store}", storeName));
      await startCoachPurchase(ad);
    } catch (error) {
      setProcessing(false);
      Alert.alert(
        t("coachCheckout.cantOpen").replace("{store}", storeName),
        error instanceof Error ? error.message : t("coachCheckout.retry")
      );
    }
  };

  return (
    <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.lg, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
        <Icon name="check-badge" size={22} color={colors.neon as string} />
        <View style={{ flex: 1 }}>
          <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("coachCheckout.title")}</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("coachCheckout.subtitle")}</Text>
        </View>
        <Text style={{ ...typography.headline, color: colors.neon }}>{price}</Text>
      </View>
      <PrimaryButton
        label={processing
          ? t("coachCheckout.verifying")
          : t("coachCheckout.buy").replace("{days}", String(COACH_PRODUCTS[ad.plan].days))}
        disabled={processing}
        onPress={() => void buy()}
      />
      <Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>
        {t("coachCheckout.footnote").replace("{store}", storeName)}
      </Text>
    </View>
  );
}
