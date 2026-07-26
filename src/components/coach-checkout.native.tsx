import { useEffect, useMemo, useRef, useState } from "react";
import { Alert, Platform, Text, View } from "react-native";
import { Icon } from "@/components/icon";
import { PrimaryButton } from "@/components/primary-button";
import { usePurchases } from "@/components/purchase-provider";
import { COACH_PRODUCTS } from "@/lib/community";
import { colors, radii, spacing, typography } from "@/theme";
import type { CoachAd } from "@/types";

export function CoachCheckout({ ad, onActivated }: { ad: CoachAd; onActivated: () => void }) {
  const [processing, setProcessing] = useState(false);
  const handledOutcome = useRef(0);
  const productId = COACH_PRODUCTS[ad.plan].id;
  const { connected, products, outcome, startCoachPurchase } = usePurchases();
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
      Alert.alert("Anuncio publicado", `Tu perfil estará destacado durante ${COACH_PRODUCTS[ad.plan].days} días.`);
      onActivated();
    } else if (outcome.message !== "Compra cancelada.") {
      Alert.alert("Pago pendiente", outcome.message || "La verificación sigue en curso.");
    }
  }, [outcome, ad.id, ad.plan, onActivated]);

  const product = useMemo(() => products.find((item) => item.id === productId), [productId, products]);
  const price = product?.displayPrice ?? COACH_PRODUCTS[ad.plan].fallbackPrice;

  const buy = async () => {
    setProcessing(true);
    try {
      if (!connected) throw new Error(`${storeName} no está disponible en este momento.`);
      await startCoachPurchase(ad);
    } catch (error) {
      setProcessing(false);
      Alert.alert(`No se pudo abrir ${storeName}`, error instanceof Error ? error.message : "Inténtalo de nuevo.");
    }
  };

  return (
    <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.lg, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
        <Icon name="check-badge" size={22} color={colors.neon as string} />
        <View style={{ flex: 1 }}>
          <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>Anuncio listo para publicar</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>Pago único · sin renovación automática</Text>
        </View>
        <Text style={{ ...typography.headline, color: colors.neon }}>{price}</Text>
      </View>
      <PrimaryButton label={processing ? "Verificando…" : `Publicar ${COACH_PRODUCTS[ad.plan].days} días`} disabled={processing} onPress={() => void buy()} />
      <Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>
        Compra procesada por {storeName}. El anuncio se activa tras validar el pago.
      </Text>
    </View>
  );
}
