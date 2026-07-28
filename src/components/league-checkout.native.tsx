import { useEffect, useRef, useState } from "react";
import { Alert, Platform, Text, View } from "react-native";
import { Icon } from "@/components/icon";
import { PrimaryButton } from "@/components/primary-button";
import { usePurchases } from "@/components/purchase-provider";
import { PRIVATE_LEAGUE_PRODUCT } from "@/lib/community";
import { colors, radii, spacing, typography } from "@/theme";
import type { PrivateLeagueInput } from "@/types";

export function LeagueCheckout({ input, onCreated }: { input: PrivateLeagueInput; onCreated: (leagueId: string) => void }) {
  const [processing, setProcessing] = useState(false);
  const [attemptId, setAttemptId] = useState<number | null>(null);
  const handledOutcome = useRef(0);
  const { connected, products, outcome, startLeaguePurchase } = usePurchases();
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
      Alert.alert("Liga creada", "Ya puedes invitar a tus amigos.");
      onCreated(outcome.leagueId);
    } else if (outcome.message !== "Compra cancelada.") {
      Alert.alert("Pago pendiente", outcome.message || "La verificación sigue en curso.");
    }
  }, [outcome, attemptId, onCreated]);
  const product = products.find((item) => item.id === PRIVATE_LEAGUE_PRODUCT.id);
  const price = product?.displayPrice ?? PRIVATE_LEAGUE_PRODUCT.fallbackPrice;
  const buy = async () => {
    setProcessing(true);
    try {
      if (!connected) throw new Error(`${storeName} no está disponible.`);
      setAttemptId(await startLeaguePurchase(input));
    } catch (error) {
      setProcessing(false);
      Alert.alert(`No se pudo abrir ${storeName}`, error instanceof Error ? error.message : "Inténtalo de nuevo.");
    }
  };
  return <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.lg, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}><View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}><Icon name="trophy" size={24} color={colors.neon as string} /><View style={{ flex: 1 }}><Text style={{ ...typography.subheadline, color: colors.textPrimary }}>Liga privada lista</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>Pago único · liga permanente</Text></View><Text style={{ ...typography.headline, color: colors.neon }}>{price}</Text></View><PrimaryButton label={processing ? "Verificando…" : "Crear liga privada"} disabled={processing} onPress={() => void buy()} /></View>;
}
