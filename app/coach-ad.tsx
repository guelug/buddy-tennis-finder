import { useEffect, useState } from "react";
import { Alert, Pressable, Text, TextInput, View } from "react-native";
import { router } from "expo-router";
import { CoachCheckout } from "@/components/coach-checkout";
import { Icon } from "@/components/icon";
import { LoadingView } from "@/components/loading-view";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { LiveBackground } from "@/components/live-visuals";
import { COACH_PRODUCTS, createCoachAdDraft, subscribeToMyCoachAds } from "@/lib/community";
import { useAuth } from "@/lib/firebase-auth";
import { getPlayer } from "@/lib/firestore";
import { useI18n } from "@/lib/i18n";
import { CITIES_BY_COUNTRY, selectableCountries } from "@/data/seed";
import { colors, radii, spacing, typography } from "@/theme";
import type { CoachAd, CoachAdPlan, Player } from "@/types";

// Ciudades reales de la app (mismo catálogo que el onboarding): Guatemala solo
// tiene "Ciudad de Guatemala", España "Barcelona"… Así nadie escribe ciudades
// que no existen y el filtro por ciudad de los jugadores siempre encuentra el
// anuncio.
const CITY_OPTIONS = selectableCountries.flatMap((country) =>
  CITIES_BY_COUNTRY[country].map((city) => ({ city, country }))
);

// Factory en render: `colors` se muta con el tema; hornearla dejaba el input
// oscuro en modo claro.
const inputStyle = () => ({
  backgroundColor: colors.surfaceElevated,
  borderColor: colors.border,
  borderRadius: radii.md,
  borderWidth: 1,
  color: colors.textPrimary,
  fontSize: 16,
  minHeight: 50,
  paddingHorizontal: spacing.md,
  paddingVertical: spacing.sm
} as const);

export default function CoachAdScreen() {
  const { user } = useAuth();
  const { t } = useI18n();
  const [player, setPlayer] = useState<Player | null>(null);
  const [headline, setHeadline] = useState("");
  const [bio, setBio] = useState("");
  const [city, setCity] = useState("");
  // Prellenado en el idioma del usuario, no en español fijo. Inicializador
  // perezoso: si cambia el idioma después no debe pisar lo que ya escribió.
  const [specialties, setSpecialties] = useState(() => t("coachAd.specialtiesPlaceholder"));
  const [priceNote, setPriceNote] = useState("");
  const [phone, setPhone] = useState("");
  const [whatsapp, setWhatsapp] = useState("");
  const [email, setEmail] = useState(user?.email ?? "");
  const [plan, setPlan] = useState<CoachAdPlan>("week");
  const [saving, setSaving] = useState(false);
  const [ad, setAd] = useState<CoachAd | null>(null);
  const [pendingAds, setPendingAds] = useState<CoachAd[]>([]);

  useEffect(() => {
    if (!user?.uid) return;
    void getPlayer(user.uid).then((value) => {
      setPlayer(value);
      if (value) setCity(value.city);
    });
  }, [user?.uid]);

  useEffect(() => user?.uid ? subscribeToMyCoachAds(user.uid, (items) => {
    setPendingAds(items.filter((item) => item.status === "pending_payment"));
  }) : undefined, [user?.uid]);

  if (!player) return <LoadingView />;

  const save = async () => {
    setSaving(true);
    try {
      const created = await createCoachAdDraft(player, {
        headline,
        bio,
        city,
        clubIds: player.clubIds,
        specialties: specialties.split(","),
        priceNote,
        plan
      }, { phone, whatsapp, email });
      setAd(created);
    } catch (error) {
      Alert.alert(t("coachAd.saveErrorTitle"), error instanceof Error ? error.message : t("coachAd.saveErrorBody"));
    } finally {
      setSaving(false);
    }
  };

  return (
    <LiveBackground overlay={0.5}>
      <ScreenShell width="base">
        <View style={{ gap: spacing.xs, paddingTop: spacing.md }}>
          <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "900", letterSpacing: 1.5 }}>{t("coachAd.kicker")}</Text>
          <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 31 }}>{t("coachAd.title")}</Text>
          <Text style={{ ...typography.body, color: colors.textSecondary }}>{t("coachAd.subtitle")}</Text>
        </View>

        {ad ? <CoachCheckout ad={ad} onActivated={() => router.replace("/coaches" as never)} /> : (
          <>
            {pendingAds.length ? (
              <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}>
                <View style={{ gap: 4 }}><Text style={{ ...typography.headline, color: colors.textPrimary }}>{pendingAds.length === 1 ? t("coachAd.pendingOne") : t("coachAd.pendingMany").replace("{count}", String(pendingAds.length))}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("coachAd.pendingHint")}</Text></View>
                {pendingAds.slice(0, 3).map((pending) => <Pressable key={pending.id} onPress={() => setAd(pending)} style={{ alignItems: "center", backgroundColor: colors.surface, borderRadius: radii.md, flexDirection: "row", gap: spacing.md, minHeight: 54, padding: spacing.md }}><View style={{ flex: 1 }}><Text numberOfLines={1} style={{ ...typography.subheadline, color: colors.textPrimary }}>{pending.headline}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("coachAd.days").replace("{count}", String(COACH_PRODUCTS[pending.plan].days))} · {COACH_PRODUCTS[pending.plan].fallbackPrice}</Text></View><Icon name="chevron-right" size={18} color={colors.neon as string} /></Pressable>)}
              </View>
            ) : null}
            <FormSection title={t("coachAd.sectionOffer")} icon="tennis">
              <Field label={t("coachAd.headline")}><TextInput value={headline} onChangeText={setHeadline} placeholder={t("coachAd.headlinePlaceholder")} placeholderTextColor={colors.textTertiary as string} maxLength={90} style={inputStyle()} /></Field>
              <Field label={t("coachAd.bio")}><TextInput value={bio} onChangeText={setBio} placeholder={t("coachAd.bioPlaceholder")} placeholderTextColor={colors.textTertiary as string} multiline maxLength={700} style={[inputStyle(), { minHeight: 130, textAlignVertical: "top" }]} /></Field>
              <Field label={t("coachAd.city")}>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
                  {CITY_OPTIONS.map((option) => {
                    const active = city === option.city;
                    return (
                      <Pressable
                        key={`${option.country}-${option.city}`}
                        accessibilityRole="radio"
                        accessibilityState={{ checked: active }}
                        onPress={() => setCity(option.city)}
                        style={{
                          backgroundColor: active ? colors.courtLight : colors.surfaceElevated,
                          borderColor: active ? colors.neon : colors.border,
                          borderRadius: radii.pill,
                          borderWidth: 1,
                          minHeight: 44,
                          paddingHorizontal: spacing.md,
                          justifyContent: "center"
                        }}
                      >
                        <Text style={{ ...typography.footnote, color: active ? colors.neon : colors.textPrimary, fontWeight: active ? "800" : "500" }}>
                          {option.city} · {option.country}
                        </Text>
                      </Pressable>
                    );
                  })}
                </View>
              </Field>
              <Field label={t("coachAd.specialties")}><TextInput value={specialties} onChangeText={setSpecialties} placeholder={t("coachAd.specialtiesPlaceholder")} placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
              <Field label={t("coachAd.priceNote")}><TextInput value={priceNote} onChangeText={setPriceNote} placeholder={t("coachAd.priceNotePlaceholder")} placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
            </FormSection>

            <FormSection title={t("coachAd.sectionContact")} icon="user">
              <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("coachAd.contactHint")}</Text>
              <Field label={t("coachAd.phone")}><TextInput value={phone} onChangeText={setPhone} keyboardType="phone-pad" placeholder="+34…" placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
              <Field label={t("coachAd.whatsapp")}><TextInput value={whatsapp} onChangeText={setWhatsapp} keyboardType="phone-pad" placeholder="+34…" placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
              <Field label={t("coachAd.email")}><TextInput value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" placeholder={t("coachAd.emailPlaceholder")} placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
            </FormSection>

            <FormSection title={t("coachAd.sectionDuration")} icon="calendar-clock">
              <View style={{ flexDirection: "row", gap: spacing.sm }}>
                {(["week", "month"] as CoachAdPlan[]).map((value) => {
                  const active = value === plan;
                  const item = COACH_PRODUCTS[value];
                  return <Pressable key={value} onPress={() => setPlan(value)} style={{ backgroundColor: active ? colors.courtLight : colors.surfaceElevated, borderColor: active ? colors.neon : colors.border, borderRadius: radii.lg, borderWidth: 1, flex: 1, gap: 4, padding: spacing.md }}><Text style={{ ...typography.headline, color: active ? colors.neon : colors.textPrimary }}>{t("coachAd.days").replace("{count}", String(item.days))}</Text><Text style={{ ...typography.caption, color: colors.textSecondary }}>{item.fallbackPrice}</Text><Text style={{ ...typography.footnote, color: colors.textTertiary }}>{t("coachAd.oneOff")}</Text></Pressable>;
                })}
              </View>
            </FormSection>
            <PrimaryButton label={saving ? t("coachAd.saving") : t("coachAd.continue")} disabled={saving} onPress={() => void save()} />
          </>
        )}
      </ScreenShell>
    </LiveBackground>
  );
}

function FormSection({ title, icon, children }: React.PropsWithChildren<{ title: string; icon: React.ComponentProps<typeof Icon>["name"] }>) {
  return <View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}><View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}><Icon name={icon} size={20} color={colors.neon as string} /><Text style={{ ...typography.headline, color: colors.textPrimary }}>{title}</Text></View>{children}</View>;
}

function Field({ label, children }: React.PropsWithChildren<{ label: string }>) {
  return <View style={{ gap: 6 }}><Text style={{ ...typography.caption, color: colors.textSecondary }}>{label}</Text>{children}</View>;
}
