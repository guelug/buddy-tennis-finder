import { useEffect, useState } from "react";
import { Text, View } from "react-native";
import { router } from "expo-router";
import Animated, { FadeInUp } from "react-native-reanimated";
import { CoachCard } from "@/components/coach-card";
import { ConceptHero } from "@/components/concept-hero";
import { Icon } from "@/components/icon";
import { LoadingView } from "@/components/loading-view";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { LiveBackground } from "@/components/live-visuals";
import { subscribeToActiveCoachAds } from "@/lib/community";
import { PURCHASES_ENABLED } from "@/lib/features";
import { colors, radii, spacing, typography } from "@/theme";
import type { CoachAd } from "@/types";

export default function CoachesScreen() {
  const [ads, setAds] = useState<CoachAd[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => subscribeToActiveCoachAds((items) => {
    setAds(items);
    setLoading(false);
  }, (reason) => {
    setError(reason.message);
    setLoading(false);
  }), []);

  if (loading) return <LoadingView />;
  return (
    <LiveBackground overlay={0.5}>
      <ScreenShell width="wide">
        <ConceptHero
          kicker="PROS DE MATCHPOINT"
          title="Entrena. Mejora. Compite."
          body="Descubre entrenadores cerca de tus clubes. Solo compartimos sus datos cuando muestras interés."
          centerLabel="PRO"
          metrics={[{ label: "Contacto protegido", value: "100%", icon: "check-badge" }, { label: "Anuncios activos", value: ads.length, icon: "users" }]}
          chips={[{ label: "Planes", value: "7 o 30 días", icon: "calendar-clock" }]}
        />
        {PURCHASES_ENABLED ? <PrimaryButton label="Quiero anunciarme" fullWidth={false} onPress={() => router.push("/coach-ad" as never)} /> : null}
        {error ? <Text selectable style={{ ...typography.body, color: colors.danger }}>{error}</Text> : null}
        {ads.length ? (
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.lg }}>
            {ads.map((ad, index) => <Animated.View key={ad.id} entering={FadeInUp.delay(index * 55)} style={{ flexBasis: 320, flexGrow: 1 }}><CoachCard ad={ad} /></Animated.View>)}
          </View>
        ) : (
          <View style={{ alignItems: "center", backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.xxl }}>
            <Icon name="tennis" size={42} color={colors.neon as string} />
            <Text style={{ ...typography.headline, color: colors.textPrimary, textAlign: "center" }}>El muro se estrena contigo</Text>
            <Text style={{ ...typography.body, color: colors.textSecondary, maxWidth: 520, textAlign: "center" }}>Aún no hay anuncios activos. Los perfiles profesionales se abrirán cuando el sistema de pagos esté disponible.</Text>
            {PURCHASES_ENABLED ? <PrimaryButton label="Crear mi anuncio" fullWidth={false} onPress={() => router.push("/coach-ad" as never)} /> : null}
          </View>
        )}
      </ScreenShell>
    </LiveBackground>
  );
}
