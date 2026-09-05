import { useEffect, useRef, useState } from "react";
import { Alert, Pressable, Text, TextInput, View } from "react-native";
import { router } from "expo-router";
import { CoachCheckout } from "@/components/coach-checkout";
import { Icon } from "@/components/icon";
import { LoadingView } from "@/components/loading-view";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { LiveBackground } from "@/components/live-visuals";
import { COACH_PRODUCTS, createCoachAdDraft, subscribeToMyCoachAds } from "@/lib/community";
import { coachAdDaysRemaining, coachAdLifecycle } from "@/lib/coach-ad-lifecycle";
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
  const [specialties, setSpecialties] = useState("");
  const [priceNote, setPriceNote] = useState("");
  const [phone, setPhone] = useState("");
  const [whatsapp, setWhatsapp] = useState("");
  const [email, setEmail] = useState(user?.email ?? "");
  const [plan, setPlan] = useState<CoachAdPlan>("week");
  const [saving, setSaving] = useState(false);
  const [ad, setAd] = useState<CoachAd | null>(null);
  const [myAds, setMyAds] = useState<CoachAd[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadFailed, setLoadFailed] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const [adsFailed, setAdsFailed] = useState(false);
  const saveInFlight = useRef(false);
  const headlineInput = useRef<TextInput>(null);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setLoadFailed(false);
    setPlayer(null);
    if (!user?.uid) {
      setLoading(false);
      return;
    }
    void getPlayer(user.uid).then((value) => {
      if (!active) return;
      setPlayer(value);
      if (value) setCity((current) => current || value.city);
    }).catch(() => {
      if (active) setLoadFailed(true);
    }).finally(() => {
      if (active) setLoading(false);
    });
    return () => { active = false; };
  }, [user?.uid, attempt]);

  useEffect(() => {
    setMyAds([]);
    setAdsFailed(false);
    return user?.uid ? subscribeToMyCoachAds(user.uid, (items) => {
      setMyAds(items);
      setAdsFailed(false);
    }, () => setAdsFailed(true)) : undefined;
  }, [user?.uid, attempt]);

  if (loading) return <LoadingView />;
  if (!player) return (
    <ScreenShell>
      <Text style={{ ...typography.body, color: colors.textPrimary }}>{t(loadFailed ? "matches.error.fallback" : "doubles.error.noProfile")}</Text>
      <PrimaryButton label={t("common.retry")} onPress={() => setAttempt((value) => value + 1)} />
      <PrimaryButton label={t("common.back")} onPress={() => router.back()} />
    </ScreenShell>
  );

  const save = async () => {
    if (saveInFlight.current) return;
    saveInFlight.current = true;
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
      saveInFlight.current = false;
      setSaving(false);
    }
  };

  const renew = (item: CoachAd) => {
    setHeadline(item.headline);
    setBio(item.bio);
    setCity(item.city);
    setSpecialties(item.specialties.join(", "));
    setPriceNote(item.priceNote ?? "");
    setPlan(item.plan);
    headlineInput.current?.focus();
  };

  const pendingAds = myAds.filter((item) => coachAdLifecycle(item) === "pending");
  const publishedAds = myAds.filter((item) => coachAdLifecycle(item) !== "pending");

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
            {adsFailed ? <View style={{ gap: spacing.sm }}>
              <Text accessibilityRole="alert" style={{ ...typography.body, color: colors.textPrimary }}>{t("matches.error.fallback")}</Text>
              <PrimaryButton label={t("common.retry")} onPress={() => setAttempt((value) => value + 1)} />
            </View> : null}
            {pendingAds.length ? (
              <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}>
                <View style={{ gap: 4 }}><Text style={{ ...typography.headline, color: colors.textPrimary }}>{pendingAds.length === 1 ? t("coachAd.pendingOne") : t("coachAd.pendingMany").replace("{count}", String(pendingAds.length))}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("coachAd.pendingHint")}</Text></View>
                {pendingAds.slice(0, 3).map((pending) => <Pressable key={pending.id} onPress={() => setAd(pending)} style={{ alignItems: "center", backgroundColor: colors.surface, borderRadius: radii.md, flexDirection: "row", gap: spacing.md, minHeight: 54, padding: spacing.md }}><View style={{ flex: 1 }}><Text numberOfLines={1} style={{ ...typography.subheadline, color: colors.textPrimary }}>{pending.headline}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("coachAd.days").replace("{count}", String(COACH_PRODUCTS[pending.plan].days))} · {COACH_PRODUCTS[pending.plan].fallbackPrice}</Text></View><Icon name="chevron-right" size={18} color={colors.neon as string} /></Pressable>)}
              </View>
            ) : null}
            {publishedAds.length ? (
              <View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}>
                <View style={{ gap: 4 }}>
                  <Text style={{ ...typography.headline, color: colors.textPrimary }}>{t("coachAd.manageTitle")}</Text>
                  <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("coachAd.manageHint")}</Text>
                </View>
                {publishedAds.slice(0, 5).map((item) => {
                  const lifecycle = coachAdLifecycle(item);
                  const days = coachAdDaysRemaining(item);
                  const isExpired = lifecycle === "expired";
                  const status = isExpired
                    ? t("coachAd.expired")
                    : lifecycle === "expiring"
                      ? t("coachAd.expiresSoon", { count: days ?? 0 })
                      : t("coachAd.activeDays", { count: days ?? COACH_PRODUCTS[item.plan].days });
                  return (
                    <View key={item.id} style={{ backgroundColor: colors.surfaceElevated, borderColor: lifecycle === "expiring" ? colors.warning : colors.border, borderRadius: radii.md, borderWidth: 1, gap: spacing.sm, padding: spacing.md }}>
                      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
                        <View style={{ flex: 1, gap: 3 }}>
                          <Text numberOfLines={1} style={{ ...typography.subheadline, color: colors.textPrimary }}>{item.headline}</Text>
                          <Text style={{ ...typography.footnote, color: isExpired ? colors.textTertiary : lifecycle === "expiring" ? colors.warning : colors.neon }}>{status}</Text>
                        </View>
                        <Icon name={isExpired ? "calendar-clock" : "check-badge"} size={20} color={(isExpired ? colors.textTertiary : lifecycle === "expiring" ? colors.warning : colors.neon) as string} />
                      </View>
                      {(isExpired || lifecycle === "expiring") ? (
                        <Pressable accessibilityRole="button" accessibilityLabel={t("coachAd.renew")} onPress={() => renew(item)} style={{ alignItems: "center", alignSelf: "flex-start", backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.pill, borderWidth: 1, minHeight: 44, justifyContent: "center", paddingHorizontal: spacing.md }}>
                          <Text style={{ ...typography.footnote, color: colors.neon, fontWeight: "800" }}>{t("coachAd.renew")}</Text>
                        </Pressable>
                      ) : null}
                    </View>
                  );
                })}
              </View>
            ) : null}
            <FormSection title={t("coachAd.sectionOffer")} icon="tennis">
              <Field label={t("coachAd.headline")}><TextInput ref={headlineInput} accessibilityLabel={t("coachAd.headline")} value={headline} onChangeText={setHeadline} placeholder={t("coachAd.headlinePlaceholder")} placeholderTextColor={colors.textTertiary as string} maxLength={90} style={inputStyle()} /></Field>
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
