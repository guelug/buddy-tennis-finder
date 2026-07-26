import { useEffect, useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import Animated, { FadeIn, FadeInUp } from "react-native-reanimated";
import { Avatar } from "@/components/avatar";
import { Chip } from "@/components/chip";
import { Icon } from "@/components/icon";
import { GlassPanel, LiveBackground } from "@/components/live-visuals";
import { LoadingView } from "@/components/loading-view";
import { PrimaryButton } from "@/components/primary-button";
import { WazeLogo } from "@/components/icons/waze-logo";
import { ScreenShell } from "@/components/screen-shell";
import { averageReviewSkills, SkillRadar, skillsFromRating } from "@/components/skill-radar";
import { getClubs, getPlayer } from "@/lib/firestore";
import { getReviewsForPlayer } from "@/lib/match-room";
import { players as seedPlayers } from "@/data/seed";
import { isFirebaseConfigured } from "@/../firebase.config";
import { levelLabel } from "@/lib/matching";
import { openInWaze } from "@/lib/waze";
import { useI18n } from "@/lib/i18n";
import { colors, radii, shadows, spacing, typography } from "@/theme";
import { Club, MatchReview, Player } from "@/types";

/**
 * Perfiles que no viven en Firestore: los de muestra del modo demo y los
 * `demo-*` que rellenan la comunidad mientras hay pocos usuarios reales.
 */
function findLocalPlayer(id: string): Player | null {
  const seedId = id.startsWith("demo-") ? id.slice("demo-".length) : id;
  const match = seedPlayers.find((item) => item.id === seedId);
  if (!match) return null;
  if (id.startsWith("demo-")) return { ...match, id, isDemo: true, profileComplete: true, responseRate: 0 };
  return isFirebaseConfigured ? null : match;
}

export default function PublicPlayerProfile() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { t } = useI18n();
  const [player, setPlayer] = useState<Player | null>(null);
  const [clubs, setClubs] = useState<Club[]>([]);
  const [reviews, setReviews] = useState<MatchReview[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!id) return;
    // Antes se descargaba la colección entera de jugadores para quedarse con
    // uno: N lecturas de Firestore por cada visita a un perfil. Ahora se lee
    // solo el documento pedido.
    Promise.all([getPlayer(id), getClubs(), getReviewsForPlayer(id)])
      .then(([remotePlayer, nextClubs, nextReviews]) => {
        setPlayer(remotePlayer ?? findLocalPlayer(id));
        setClubs(nextClubs);
        setReviews(nextReviews);
      })
      .catch(() => setPlayer(findLocalPlayer(id)))
      .finally(() => setLoading(false));
  }, [id]);

  const skillSummary = useMemo(
    () => averageReviewSkills(
      reviews.map((review) => review.skillRatings),
      player?.skills ?? skillsFromRating(player?.rating ?? 3)
    ),
    [player, reviews]
  );

  if (loading) return <LoadingView />;
  if (!player) {
    return (
      <LiveBackground>
        <ScreenShell topSafe bottomInset={16}>
          <BackButton />
          <GlassPanel>
            <Text style={{ ...typography.title, color: colors.textPrimary }}>{t("player.unavailable.title")}</Text>
            <Text style={{ ...typography.body, color: colors.textSecondary }}>{t("player.unavailable.body")}</Text>
          </GlassPanel>
        </ScreenShell>
      </LiveBackground>
    );
  }

  const playerClubs = clubs.filter((club) => player.clubIds.includes(club.id));
  return (
    <LiveBackground overlay={0.54}>
      <ScreenShell width="base" topSafe bottomInset={16}>
        <BackButton />
        <Animated.View entering={FadeInUp.springify().damping(20)}>
          <GlassPanel>
            <View style={{ alignItems: "center", gap: spacing.sm }}>
              <View style={{ borderColor: `${colors.neon}88`, borderRadius: 999, borderWidth: 3, boxShadow: shadows.courtGlow, padding: 4 }}>
                <Avatar name={player.name} photoURL={player.photoURL} size={112} />
              </View>
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
                <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 27 }}>{player.name}</Text>
                {player.verified ? <Icon name="check-badge" size={19} color={colors.hardCourt as string} /> : null}
              </View>
              <Text style={{ ...typography.body, color: colors.textSecondary }}>{t("player.yearsLevel", { age: player.age, level: levelLabel(player.level), rating: player.rating.toFixed(1) })}</Text>
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs, justifyContent: "center" }}>
                {player.preferredFormats.map((format) => <Chip key={format} label={formatLabel(format)} active />)}
              </View>
              {player.bio ? <Text style={{ ...typography.body, color: colors.textSecondary, lineHeight: 21, textAlign: "center" }}>{player.bio}</Text> : null}
            </View>
            <View style={{ flexDirection: "row", gap: spacing.sm }}>
              <Stat value={`${player.responseRate}%`} label={t("player.response")} />
              <Stat value={`${reviews.length}`} label={t("player.reviews")} />
              <Stat value={levelLabel(player.level)} label={t("player.category")} />
            </View>
          </GlassPanel>
        </Animated.View>

        <Animated.View entering={FadeIn.delay(90).springify()}>
          <GlassPanel>
            <Text style={{ ...typography.headline, color: colors.textPrimary }}>{t("profile.skills.title")}</Text>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{skillSummary.count ? t("profile.skills.hintReviews", { count: skillSummary.count }) : t("player.skills.estimate")}</Text>
            <SkillRadar skills={skillSummary.skills} size={260} provisional={skillSummary.count === 0} />
          </GlassPanel>
        </Animated.View>

        <GlassPanel>
          <Text style={{ ...typography.headline, color: colors.textPrimary }}>{t("player.clubs")}</Text>
          {playerClubs.map((club) => (
            <Pressable key={club.id} onPress={() => openInWaze(club.latitude, club.longitude, club.name)} style={{ alignItems: "center", borderTopColor: colors.border, borderTopWidth: 1, flexDirection: "row", gap: spacing.md, paddingVertical: spacing.md }}>
              <Icon name="building" size={18} color={colors.neon as string} />
              <View style={{ flex: 1 }}><Text style={{ ...typography.bodyEmphasized, color: colors.textPrimary }}>{club.name}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{club.city} · {t("profile.clubs.courts", { count: club.courts })}</Text></View>
              <WazeLogo size={18} color={colors.court} />
            </Pressable>
          ))}
        </GlassPanel>

        <GlassPanel>
          <Text style={{ ...typography.headline, color: colors.textPrimary }}>{t("profile.availability.title")}</Text>
          {player.availability.length ? player.availability.map((slot) => (
            <View key={slot.day} style={{ alignItems: "center", borderTopColor: colors.border, borderTopWidth: 1, flexDirection: "row", justifyContent: "space-between", paddingVertical: spacing.sm }}><Text style={{ ...typography.body, color: colors.textPrimary }}>{slot.day}</Text><Text style={{ ...typography.caption, color: colors.neon }}>{slot.ranges.join(", ")}</Text></View>
          )) : <Text style={{ ...typography.body, color: colors.textSecondary }}>{t("player.noAvailability")}</Text>}
        </GlassPanel>

        <PrimaryButton label={t("player.openMatches")} icon={<Icon name="calendar-plus" size={17} color={colors.textOnBall as string} />} onPress={() => router.replace("/")} />
      </ScreenShell>
    </LiveBackground>
  );
}

function BackButton() {
  return (
    <Pressable
      accessibilityRole="button"
      hitSlop={10}
      onPress={() => router.back()}
      style={{
        alignItems: "center",
        alignSelf: "flex-start",
        backgroundColor: colors.surface,
        borderColor: colors.borderStrong,
        borderRadius: radii.pill,
        borderWidth: 1,
        flexDirection: "row",
        gap: spacing.xs,
        minHeight: 40,
        paddingHorizontal: spacing.md,
        paddingVertical: spacing.sm
      }}
    >
      <Text style={{ color: colors.neon, fontSize: 20 }}>‹</Text>
      <Text style={{ ...typography.caption, color: colors.textPrimary }}>Volver</Text>
    </Pressable>
  );
}

function Stat({ value, label }: { value: string; label: string }) {
  return <View style={{ alignItems: "center", backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.md, borderWidth: 1, flex: 1, padding: spacing.sm }}><Text style={{ ...typography.headline, color: colors.neon, fontSize: 20 }}>{value}</Text><Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>{label}</Text></View>;
}

function formatLabel(format: Player["preferredFormats"][number]) {
  return format === "singles" ? "Singles" : format === "doubles" ? "Dobles" : "Mixto";
}
