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
  const [player, setPlayer] = useState<Player | null>(null);
  const [headline, setHeadline] = useState("");
  const [bio, setBio] = useState("");
  const [city, setCity] = useState("");
  const [specialties, setSpecialties] = useState("Iniciación, Técnica, Competición");
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
      Alert.alert("Revisa el anuncio", error instanceof Error ? error.message : "No pudimos guardar el anuncio.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <LiveBackground overlay={0.5}>
      <ScreenShell width="base">
        <View style={{ gap: spacing.xs, paddingTop: spacing.md }}>
          <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "900", letterSpacing: 1.5 }}>TU ESCAPARATE PROFESIONAL</Text>
          <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 31 }}>Anúnciate como entrenador</Text>
          <Text style={{ ...typography.body, color: colors.textSecondary }}>Crea una tarjeta clara y deja que cada jugador desbloquee tus datos al mostrar interés.</Text>
        </View>

        {ad ? <CoachCheckout ad={ad} onActivated={() => router.replace("/coaches" as never)} /> : (
          <>
            {pendingAds.length ? (
              <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}>
                <View style={{ gap: 4 }}><Text style={{ ...typography.headline, color: colors.textPrimary }}>Tienes {pendingAds.length === 1 ? "un anuncio pendiente" : `${pendingAds.length} anuncios pendientes`}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>Puedes retomar el pago guardado desde web o de una sesión anterior.</Text></View>
                {pendingAds.slice(0, 3).map((pending) => <Pressable key={pending.id} onPress={() => setAd(pending)} style={{ alignItems: "center", backgroundColor: colors.surface, borderRadius: radii.md, flexDirection: "row", gap: spacing.md, minHeight: 54, padding: spacing.md }}><View style={{ flex: 1 }}><Text numberOfLines={1} style={{ ...typography.subheadline, color: colors.textPrimary }}>{pending.headline}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{COACH_PRODUCTS[pending.plan].days} días · {COACH_PRODUCTS[pending.plan].fallbackPrice}</Text></View><Icon name="chevron-right" size={18} color={colors.neon as string} /></Pressable>)}
              </View>
            ) : null}
            <FormSection title="Tu propuesta" icon="tennis">
              <Field label="Titular"><TextInput value={headline} onChangeText={setHeadline} placeholder="Ej. Mejora tu tenis con sesiones a medida" placeholderTextColor={colors.textTertiary as string} maxLength={90} style={inputStyle()} /></Field>
              <Field label="Preséntate"><TextInput value={bio} onChangeText={setBio} placeholder="Experiencia, metodología y a quién ayudas…" placeholderTextColor={colors.textTertiary as string} multiline maxLength={700} style={[inputStyle(), { minHeight: 130, textAlignVertical: "top" }]} /></Field>
              <Field label="Ciudad">
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
              <Field label="Especialidades (separadas por comas)"><TextInput value={specialties} onChangeText={setSpecialties} placeholder="Iniciación, Técnica, Competición" placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
              <Field label="Precio o llamada a la acción (opcional)"><TextInput value={priceNote} onChangeText={setPriceNote} placeholder="Desde 25 €/hora" placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
            </FormSection>

            <FormSection title="Contacto privado" icon="user">
              <Text style={{ ...typography.footnote, color: colors.textSecondary }}>No aparece en el muro. Solo se revela después de que un jugador pulse “Estoy interesado”.</Text>
              <Field label="Teléfono"><TextInput value={phone} onChangeText={setPhone} keyboardType="phone-pad" placeholder="+34…" placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
              <Field label="WhatsApp"><TextInput value={whatsapp} onChangeText={setWhatsapp} keyboardType="phone-pad" placeholder="+34…" placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
              <Field label="Email"><TextInput value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" placeholder="tu@email.com" placeholderTextColor={colors.textTertiary as string} style={inputStyle()} /></Field>
            </FormSection>

            <FormSection title="Duración" icon="calendar-clock">
              <View style={{ flexDirection: "row", gap: spacing.sm }}>
                {(["week", "month"] as CoachAdPlan[]).map((value) => {
                  const active = value === plan;
                  const item = COACH_PRODUCTS[value];
                  return <Pressable key={value} onPress={() => setPlan(value)} style={{ backgroundColor: active ? colors.courtLight : colors.surfaceElevated, borderColor: active ? colors.neon : colors.border, borderRadius: radii.lg, borderWidth: 1, flex: 1, gap: 4, padding: spacing.md }}><Text style={{ ...typography.headline, color: active ? colors.neon : colors.textPrimary }}>{item.days} días</Text><Text style={{ ...typography.caption, color: colors.textSecondary }}>{item.fallbackPrice}</Text><Text style={{ ...typography.footnote, color: colors.textTertiary }}>Pago único</Text></Pressable>;
                })}
              </View>
            </FormSection>
            <PrimaryButton label={saving ? "Guardando…" : "Continuar al pago"} disabled={saving} onPress={() => void save()} />
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
