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
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography } from "@/theme";
import type { CoachAd } from "@/types";

export default function CoachesScreen() {
  const { t } = useI18n();
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
          kicker={t("coaches.kicker")}
          title={t("coaches.title")}
          body={t("coaches.body")}
          centerLabel="PRO"
          metrics={[
            { label: t("coaches.protectedContact"), value: "100%", icon: "check-badge" },
            { label: t("coaches.activeAds"), value: ads.length, icon: "users" }
          ]}
          chips={[{ label: t("coaches.plans"), value: t("coaches.daysRange"), icon: "calendar-clock" }]}
        />
        {PURCHASES_ENABLED ? <PrimaryButton label={t("coaches.advertise")} fullWidth={false} onPress={() => router.push("/coach-ad" as never)} /> : null}
        {error ? <Text selectable style={{ ...typography.body, color: colors.danger }}>{error}</Text> : null}
        {ads.length ? (
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.lg }}>
            {ads.map((ad, index) => <Animated.View key={ad.id} entering={FadeInUp.delay(index * 55)} style={{ flexBasis: 320, flexGrow: 1 }}><CoachCard ad={ad} /></Animated.View>)}
          </View>
        ) : (
          <View style={{ alignItems: "center", backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.xxl }}>
            <Icon name="tennis" size={42} color={colors.neon as string} />
            <Text style={{ ...typography.headline, color: colors.textPrimary, textAlign: "center" }}>{t("coaches.empty.title")}</Text>
            <Text style={{ ...typography.body, color: colors.textSecondary, maxWidth: 520, textAlign: "center" }}>{t("coaches.empty.body")}</Text>
            {PURCHASES_ENABLED ? <PrimaryButton label={t("coaches.empty.cta")} fullWidth={false} onPress={() => router.push("/coach-ad" as never)} /> : null}
          </View>
        )}
      </ScreenShell>
    </LiveBackground>
  );
}
