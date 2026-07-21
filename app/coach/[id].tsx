import { useEffect, useState } from "react";
import { Alert, Linking, Pressable, Text, View } from "react-native";
import { useLocalSearchParams } from "expo-router";
import Animated, { FadeInUp } from "react-native-reanimated";
import { Avatar } from "@/components/avatar";
import { Chip } from "@/components/chip";
import { Icon } from "@/components/icon";
import { LoadingView } from "@/components/loading-view";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { LiveBackground } from "@/components/live-visuals";
import { expressCoachInterest, getCoachAd } from "@/lib/community";
import { useAuth } from "@/lib/firebase-auth";
import { getPlayer } from "@/lib/firestore";
import { colors, radii, shadows, spacing, typography } from "@/theme";
import type { CoachAd, CoachContact, Player } from "@/types";

export default function CoachDetailScreen() {
  const params = useLocalSearchParams<{ id: string }>();
  const { user } = useAuth();
  const [ad, setAd] = useState<CoachAd | null>(null);
  const [player, setPlayer] = useState<Player | null>(null);
  const [contact, setContact] = useState<CoachContact | null>(null);
  const [loading, setLoading] = useState(true);
  const [revealing, setRevealing] = useState(false);

  useEffect(() => {
    void Promise.all([getCoachAd(params.id), user?.uid ? getPlayer(user.uid) : Promise.resolve(null)]).then(([adValue, playerValue]) => {
      setAd(adValue);
      setPlayer(playerValue);
      setLoading(false);
    });
  }, [params.id, user?.uid]);

  if (loading) return <LoadingView />;
  if (!ad) return <LiveBackground overlay={0.5}><ScreenShell><Text selectable style={{ ...typography.headline, color: colors.textPrimary }}>Este anuncio ya no está disponible.</Text></ScreenShell></LiveBackground>;

  const reveal = async () => {
    if (!player) return;
    setRevealing(true);
    try {
      setContact(await expressCoachInterest(ad.id, player));
    } catch (error) {
      Alert.alert("No pudimos abrir el contacto", error instanceof Error ? error.message : "Inténtalo de nuevo.");
    } finally {
      setRevealing(false);
    }
  };

  const ownAd = ad.ownerId === user?.uid;
  return (
    <LiveBackground overlay={0.48}>
      <ScreenShell width="base">
        <Animated.View entering={FadeInUp.springify().damping(19)} style={{ alignItems: "center", gap: spacing.md, paddingTop: spacing.xl }}>
          <View style={{ borderColor: `${colors.neon}88`, borderRadius: 999, borderWidth: 3, boxShadow: shadows.courtGlow, padding: 4 }}><Avatar name={ad.coachName} photoURL={ad.photoURL} size={112} /></View>
          <View style={{ alignItems: "center", gap: 4 }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: 7 }}><Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 31 }}>{ad.coachName}</Text><Icon name="check-badge" size={21} color={colors.neon as string} /></View>
            <Text style={{ ...typography.caption, color: colors.textSecondary }}>{ad.city}</Text>
          </View>
        </Animated.View>

        <View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}>
          <Text style={{ ...typography.title, color: colors.neon, fontSize: 25 }}>{ad.headline}</Text>
          <Text selectable style={{ ...typography.body, color: colors.textSecondary, lineHeight: 24 }}>{ad.bio}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>{ad.specialties.map((item) => <Chip key={item} label={item} active />)}</View>
          {ad.priceNote ? <Text style={{ ...typography.headline, color: colors.gold }}>{ad.priceNote}</Text> : null}
        </View>

        {contact ? <ContactPanel contact={contact} /> : ownAd ? (
          <View style={{ backgroundColor: colors.infoBg, borderColor: `${colors.info}44`, borderRadius: radii.lg, borderWidth: 1, padding: spacing.lg }}><Text style={{ ...typography.body, color: colors.textPrimary }}>Este es tu anuncio. Recibirás una notificación en tu perfil cuando un jugador muestre interés.</Text></View>
        ) : (
          <View style={{ gap: spacing.sm }}>
            <PrimaryButton label={revealing ? "Abriendo contacto…" : "Estoy interesado"} disabled={revealing || !player} icon={<Icon name="send" size={18} color={colors.textOnBrand as string} />} onPress={() => void reveal()} />
            <Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>Al continuar, el entrenador verá tu nombre y recibirá una notificación dentro de MatchPoint.</Text>
          </View>
        )}
      </ScreenShell>
    </LiveBackground>
  );
}

function ContactPanel({ contact }: { contact: CoachContact }) {
  const rows = [
    contact.whatsapp ? { label: "WhatsApp", value: contact.whatsapp, url: `https://wa.me/${contact.whatsapp.replace(/\D/g, "")}` } : null,
    contact.phone ? { label: "Teléfono", value: contact.phone, url: `tel:${contact.phone}` } : null,
    contact.email ? { label: "Email", value: contact.email, url: `mailto:${contact.email}` } : null,
    contact.website ? { label: "Web", value: contact.website, url: contact.website.startsWith("http") ? contact.website : `https://${contact.website}` } : null
  ].filter(Boolean) as Array<{ label: string; value: string; url: string }>;
  return <View style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}66`, borderRadius: radii.xl, borderWidth: 1, gap: spacing.sm, padding: spacing.lg }}><View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}><Icon name="check-badge" size={22} color={colors.neon as string} /><Text style={{ ...typography.headline, color: colors.textPrimary }}>Contacto desbloqueado</Text></View>{rows.map((row) => <Pressable key={row.label} onPress={() => void Linking.openURL(row.url)} style={{ alignItems: "center", backgroundColor: colors.surface, borderRadius: radii.md, flexDirection: "row", gap: spacing.md, minHeight: 52, paddingHorizontal: spacing.md }}><Text style={{ ...typography.caption, color: colors.textTertiary, width: 72 }}>{row.label}</Text><Text selectable style={{ ...typography.body, color: colors.textPrimary, flex: 1 }}>{row.value}</Text><Icon name="chevron-right" size={16} color={colors.neon as string} /></Pressable>)}</View>;
}
