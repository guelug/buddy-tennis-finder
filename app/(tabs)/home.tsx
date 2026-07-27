import { useCallback, useEffect, useMemo, useState } from "react";
import { Image, ImageBackground, Platform, Pressable, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import Animated, { FadeIn, FadeInUp } from "react-native-reanimated";
import { Avatar } from "@/components/avatar";
import { BrandLockup } from "@/components/brand-lockup";
import { Card } from "@/components/card";
import { CoachCard } from "@/components/coach-card";
import { Icon, type IconName } from "@/components/icon";
import { LiveBackground } from "@/components/live-visuals";
import { PrimaryButton } from "@/components/primary-button";
import { MatchBuddyAvatar, useMatchBuddy } from "@/components/match-buddy-picker";
import { ScreenShell } from "@/components/screen-shell";
import { WazeLogo } from "@/components/icons/waze-logo";
import { getHomeData } from "@/lib/app-api";
import { subscribeToActiveCoachAds, subscribeToCoachInterests } from "@/lib/community";
import { useAuth } from "@/lib/firebase-auth";
import { PURCHASES_ENABLED } from "@/lib/features";
import { shareAppInvite } from "@/lib/share";
import { openInWaze } from "@/lib/waze";
import { getHomeCountryContent } from "@/data/home-content";
import { useI18n } from "@/lib/i18n";
import { broadcast, colors, radii, shadows, spacing, typography, usePlatformLayout, useThemeMode } from "@/theme";
import { Club, CoachAd, CoachInterest, MatchProposal, Player } from "@/types";

const courtImageDark = require("@/../assets/generated/bg-home-card-dark.jpg");
const courtImageLight = require("@/../assets/generated/bg-home-card-light.jpg");
const tournamentImage = require("@/../assets/generated/player-carlos.webp");
const communityImage = require("@/../assets/generated/bg-rival-radar.webp");
const productOne = require("@/../assets/icon.png");
const productTwo = require("@/../assets/generated/tennis-ball-realistic.webp");
const iconSearchDark = require("@/../assets/generated/home-icons/search.png");
const iconSearchLight = require("@/../assets/generated/home-icons/search-light.png");
const iconReserveDark = require("@/../assets/generated/home-icons/reserve.png");
const iconReserveLight = require("@/../assets/generated/home-icons/reserve-light.png");
const iconRankingDark = require("@/../assets/generated/home-icons/ranking.png");
const iconRankingLight = require("@/../assets/generated/home-icons/ranking-light.png");
const iconPublishDark = require("@/../assets/generated/home-icons/publish.png");
const iconPublishLight = require("@/../assets/generated/home-icons/publish-light.png");

export default function HomeScreen() {
  const { isLight } = useThemeMode();
  const { user } = useAuth();
  const { t } = useI18n();
  const { isWebDesktop } = usePlatformLayout();
  const [player, setPlayer] = useState<Player | null>(null);
  const [clubs, setClubs] = useState<Club[]>([]);
  const [proposals, setProposals] = useState<MatchProposal[]>([]);
  const [coachAds, setCoachAds] = useState<CoachAd[]>([]);
  const [coachInterests, setCoachInterests] = useState<CoachInterest[]>([]);
  const [error, setError] = useState<string | null>(null);

  const loadHome = useCallback(async () => {
    try {
      const home = await getHomeData(undefined, user?.uid);
      setPlayer(home.currentPlayer);
      setClubs(home.clubs);
      setProposals(home.proposals);
      setError(null);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : t("home.error"));
    }
  }, [user?.uid, t]);

  useEffect(() => {
    void loadHome();
  }, [loadHome]);

  useEffect(() => {
    const stopAds = subscribeToActiveCoachAds(setCoachAds);
    const stopInterests = user?.uid ? subscribeToCoachInterests(user.uid, setCoachInterests) : () => {};
    return () => { stopAds(); stopInterests(); };
  }, [user?.uid]);

  const nextMatch = useMemo(() => proposals.filter((proposal) => proposal.status === "accepted" && new Date(proposal.startsAt).getTime() > Date.now()).sort((a, b) => a.startsAt.localeCompare(b.startsAt))[0], [proposals]);
  const nextClub = clubs.find((club) => club.id === nextMatch?.clubId);
  const content = getHomeCountryContent(player?.country ?? "Guatemala");

  return (
    <LiveBackground overlay={0.58}>
      <SafeAreaView edges={["top"]} style={{ flex: 1 }}>
      <ScreenShell width={isWebDesktop ? "wide" : "base"} bottomInset={isWebDesktop ? 64 : 8} onRefresh={loadHome}>
        <HomeHeader player={player} intro={content.intro} isDesktop={isWebDesktop} isLight={isLight} />

        {error ? (
          <Card style={{ backgroundColor: colors.warningBg, borderColor: `${colors.warning}55` }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
              <Icon name="clock" size={20} color={colors.warning as string} />
              <Text selectable style={{ ...typography.body, color: colors.textPrimary, flex: 1 }}>{error}</Text>
              <Pressable accessibilityRole="button" onPress={() => void loadHome()}>
                <Text style={{ ...typography.caption, color: colors.warning, fontWeight: "900" }}>{t("common.retry").toUpperCase()}</Text>
              </Pressable>
            </View>
          </Card>
        ) : null}

        {coachInterests.some((item) => !item.readAt) ? (
          <Pressable onPress={() => router.push("/coach-interests" as never)} style={{ alignItems: "center", backgroundColor: colors.goldSoft, borderColor: `${colors.gold}66`, borderRadius: radii.lg, borderWidth: 1, flexDirection: "row", gap: spacing.md, padding: spacing.md }}>
            <Icon name="users" size={22} color={colors.gold as string} />
            <View style={{ flex: 1 }}><Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("home.coachInterests.title")}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("home.coachInterests.subtitle")}</Text></View>
            <View style={{ alignItems: "center", backgroundColor: colors.gold, borderRadius: 999, height: 28, justifyContent: "center", width: 28 }}><Text style={{ ...typography.caption, color: colors.textOnBall }}>{coachInterests.filter((item) => !item.readAt).length}</Text></View>
          </Pressable>
        ) : null}

        {isWebDesktop ? (
          <View style={{ alignItems: "stretch", flexDirection: "row", gap: spacing.xl }}>
            <View style={{ flex: 1.7, minWidth: 0 }}><NextMatchCard proposal={nextMatch} club={nextClub} player={player} desktop /></View>
            <DesktopPulse player={player} proposals={proposals} clubs={clubs} />
          </View>
        ) : <NextMatchCard proposal={nextMatch} club={nextClub} player={player} />}

        <InviteFriendsCard playerName={player?.name} desktop={isWebDesktop} />

        <SectionTitle title={t("home.tennisIn.title").replace("{country}", content.countryLabel)} subtitle={t("home.tennisIn.subtitle")} />
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: isWebDesktop ? spacing.lg : spacing.sm }}>
          {content.stories.map((story, index) => <StoryCard key={story.title} {...story} index={index} image={index ? communityImage : tournamentImage} desktop={isWebDesktop} />)}
        </View>

        <View style={{ gap: spacing.md }}>
            <SectionTitle title={t("home.coaches.title")} subtitle={t("home.coaches.subtitle")} trailing={coachAds.length ? t("home.promoted") : undefined} />
            {coachAds.length ? (
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
              {coachAds.slice(0, isWebDesktop ? 3 : 2).map((ad) => <CoachCard key={ad.id} ad={ad} compact />)}
            </View>
            ) : (
              <Card style={{ alignItems: "center", gap: spacing.sm }}>
                <Icon name="users" size={30} color={colors.neon as string} />
                <Text style={{ ...typography.subheadline, color: colors.textPrimary, textAlign: "center" }}>{t("coaches.empty.title")}</Text>
                <Text style={{ ...typography.footnote, color: colors.textSecondary, textAlign: "center" }}>{t("coaches.empty.body")}</Text>
              </Card>
            )}
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
              <PrimaryButton label={t("home.viewAll")} fullWidth={false} onPress={() => router.push("/coaches" as never)} />
              {PURCHASES_ENABLED ? <PrimaryButton label={t("home.promoteAsCoach")} variant="outline" fullWidth={false} onPress={() => router.push("/coach-ad" as never)} /> : null}
            </View>
          </View>

        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: isWebDesktop ? spacing.lg : spacing.sm }}>
          <QuickAction
            imageDark={iconPublishDark}
            imageLight={iconPublishLight}
            label="MatchPoint Assistant"
            detail="Pregunta por tus estadísticas, partidos y torneos"
            desktop={isWebDesktop}
            onPress={() => router.push("/assistant" as never)}
          />
          <QuickAction
            imageDark={iconSearchDark}
            imageLight={iconSearchLight}
            label={t("home.quick.rivals")}
            detail={t("home.quick.rivalsDetail")}
            desktop={isWebDesktop}
            onPress={() => router.push("/")}
          />
          <QuickAction
            imageDark={iconReserveDark}
            imageLight={iconReserveLight}
            label={t("home.quick.publish")}
            detail={t("home.quick.publishDetail")}
            desktop={isWebDesktop}
            onPress={() => router.push({ pathname: "/", params: { publish: "1" } })}
          />
          <QuickAction
            imageDark={iconRankingDark}
            imageLight={iconRankingLight}
            label={t("tabs.ranking")}
            detail={t("home.quick.rankingDetail")}
            desktop={isWebDesktop}
            onPress={() => router.push("/liga")}
          />
          <QuickAction
            imageDark={iconPublishDark}
            imageLight={iconPublishLight}
            label={t("profile.inviteShort")}
            detail={t("profile.inviteHint")}
            desktop={isWebDesktop}
            onPress={() => router.push("/invite" as never)}
          />
          <QuickAction
            imageDark={iconSearchDark}
            imageLight={iconSearchLight}
            label={t("nav.coaches")}
            detail={t("home.coaches.subtitle")}
            desktop={isWebDesktop}
            onPress={() => router.push("/coaches" as never)}
          />
        </View>

        <SectionTitle title={t("home.selection.title")} subtitle={t("home.selection.subtitle")} trailing={t("home.sponsored")} />
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: isWebDesktop ? spacing.lg : spacing.sm }}>
          {content.commerce.map((item, index) => <CommerceCard key={item.name} {...item} image={index ? productTwo : productOne} desktop={isWebDesktop} />)}
        </View>

        <Card pad={isWebDesktop ? "xl" : "lg"} style={isWebDesktop ? { backgroundColor: isLight ? "rgba(255,255,255,.94)" : "rgba(10,19,13,.86)", borderColor: isLight ? colors.border : `${colors.neon}33` } : undefined}>
          <Text style={{ ...typography.headline, color: colors.textPrimary }}>{t("home.community.title")}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: isWebDesktop ? spacing.lg : spacing.sm }}><CommunityStat icon="users" value={0} label={t("home.stats.members")} desktop={isWebDesktop} /><CommunityStat icon="calendar-clock" value={proposals.filter((item) => item.status === "accepted").length} label={t("tabs.matches")} desktop={isWebDesktop} /><CommunityStat icon="trophy" value={0} label={t("home.stats.tournaments")} desktop={isWebDesktop} /><CommunityStat icon="building" value={clubs.length} label={t("home.stats.clubs")} desktop={isWebDesktop} /></View>
        </Card>
      </ScreenShell>
      </SafeAreaView>
    </LiveBackground>
  );
}

function HomeHeader({ player, intro, isDesktop, isLight }: { player: Player | null; intro: string; isDesktop: boolean; isLight: boolean }) {
  const { t } = useI18n();
  const { buddy } = useMatchBuddy();
  const greeting = t(greetingKeyForCurrentTime());
  if (!isDesktop) {
    return (
      <View style={{ gap: spacing.md, paddingTop: spacing.sm }}>
        <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
          <BrandLockup size="md" light={isLight} />
          <Pressable accessibilityLabel={`Hablar con ${buddy.name}`} onPress={() => router.push("/assistant" as never)} style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
            <View style={{ alignItems: "flex-end" }}>
              <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "900" }}>MATCH BUDDY</Text>
              <Text style={{ ...typography.footnote, color: colors.textPrimary }}>{buddy.name}</Text>
            </View>
            <MatchBuddyAvatar size={52} />
          </Pressable>
        </View>
        <Animated.View entering={FadeInUp.springify().damping(20)} style={{ gap: spacing.xs }}>
          <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 27 }}>{greeting}, <Text style={{ color: colors.neon }}>{player?.name?.split(" ")[0] ?? t("home.playerFallback")}</Text></Text>
          <Text style={{ ...typography.body, color: colors.textSecondary }}>{intro}</Text>
        </Animated.View>
      </View>
    );
  }
  // Desktop: el TopNav ya muestra el BrandLockup y el toggle de tema — aquí solo el saludo.
  return (
    <Animated.View entering={FadeInUp.springify().damping(20)} style={{ gap: spacing.xs, maxWidth: 720, paddingTop: spacing.lg }}>
      <Text style={{ ...broadcast.jersey, color: colors.neon, letterSpacing: 2 }}>{t("tabs.home").toUpperCase()}</Text>
      <Text style={{ ...broadcast.hero, color: colors.textPrimary, fontSize: 38, lineHeight: 40 }}>{greeting}, <Text style={{ color: colors.neon }}>{player?.name?.split(" ")[0] ?? t("home.playerFallback")}</Text></Text>
      <Text style={{ ...typography.body, color: colors.textSecondary }}>{intro}</Text>
    </Animated.View>
  );
}

function greetingKeyForCurrentTime() {
  const hour = new Date().getHours();
  if (hour < 6) return "home.greeting.night";
  if (hour < 12) return "home.greeting.morning";
  if (hour < 20) return "home.greeting.afternoon";
  return "home.greeting.night";
}

function DesktopPulse({ player, proposals, clubs }: { player: Player | null; proposals: MatchProposal[]; clubs: Club[] }) {
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  return (
    <Card
      pad="xl"
      style={{
        backgroundColor: isLight ? "rgba(255,255,255,0.92)" : "rgba(8,18,11,.84)",
        borderColor: isLight ? "rgba(55,91,42,0.16)" : `${colors.neon}33`,
        flex: 1,
        justifyContent: "space-between",
        minWidth: 320
      }}
    >
      <View style={{ gap: spacing.xs }}>
        <Text style={{ ...broadcast.jersey, color: colors.neon, letterSpacing: 2 }}>{t("home.pulse.eyebrow")}</Text>
        <Text style={{ ...broadcast.hero, color: colors.textPrimary, fontSize: 31, lineHeight: 33 }}>
          {t("home.pulse.title")}
        </Text>
        <Text style={{ ...typography.body, color: colors.textSecondary }}>
          {t("home.pulse.subtitle")}
        </Text>
      </View>
      <View style={{ flexDirection: "row", gap: spacing.sm }}>
        <PulseMetric value={player?.rating?.toFixed(1) ?? "—"} label={t("home.pulse.rating")} />
        <PulseMetric value={proposals.length} label={t("home.pulse.matches")} />
        <PulseMetric value={clubs.length} label={t("home.pulse.clubs")} />
      </View>
      <PrimaryButton
        label={t("home.pulse.cta")}
        icon={
          <Image
            source={isLight ? iconSearchLight : iconSearchDark}
            style={{ height: 22, width: 22, borderRadius: 6 }}
          />
        }
        onPress={() => router.push("/")}
      />
    </Card>
  );
}

function PulseMetric({ value, label }: { value: string | number; label: string }) { return <View style={{ backgroundColor: colors.courtLight, borderRadius: radii.md, flex: 1, padding: spacing.md }}><Text style={{ ...broadcast.stat, color: colors.neon, fontSize: 25 }}>{value}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{label}</Text></View>; }

function NextMatchCard({ proposal, club, player, desktop = false }: { proposal?: MatchProposal; club?: Club; player: Player | null; desktop?: boolean }) {
  const { isLight } = useThemeMode();
  const { t, lang } = useI18n();
  const heroBg = isLight ? courtImageLight : courtImageDark;
  if (!proposal || !club) {
    return (
      <ImageBackground
        source={heroBg}
        imageStyle={{ borderRadius: radii.xl }}
        style={{ borderColor: `${colors.neon}55`, borderRadius: radii.xl, borderWidth: 1, overflow: "hidden" }}
      >
        <View
          style={{
            backgroundColor: isLight ? "rgba(255,255,255,.62)" : "rgba(4,10,6,.70)",
            gap: spacing.md,
            minHeight: desktop ? 360 : 210,
            justifyContent: "flex-end",
            padding: desktop ? spacing.xxl : spacing.lg
          }}
        >
          <Text style={{ ...broadcast.jersey, color: colors.neon, fontWeight: "900", letterSpacing: 2 }}>
            {t("home.nextMatch.eyebrow")}
          </Text>
          <Text
            style={{
              ...(desktop ? broadcast.hero : typography.title),
              color: isLight ? colors.textPrimary : "#fff",
              fontSize: desktop ? 42 : 28,
              lineHeight: desktop ? 44 : 32
            }}
          >
            {t("home.nextMatch.emptyTitle")}
          </Text>
          <Text
            style={{
              ...typography.body,
              color: isLight ? colors.textSecondary : "rgba(255,255,255,.72)",
              maxWidth: 520
            }}
          >
            {t("home.nextMatch.emptySubtitle")}
          </Text>
          <View style={{ maxWidth: desktop ? 260 : undefined }}>
            <PrimaryButton
              label={t("home.nextMatch.cta")}
              icon={
                <Image
                  source={isLight ? iconSearchLight : iconSearchDark}
                  style={{ height: 22, width: 22, borderRadius: 6 }}
                />
              }
              onPress={() => router.push("/")}
            />
          </View>
        </View>
      </ImageBackground>
    );
  }
  const date = new Date(proposal.startsAt);
  return (
    <Animated.View entering={FadeIn.delay(60).springify()}>
      <ImageBackground
        source={heroBg}
        imageStyle={{ borderRadius: radii.xl }}
        style={{ borderColor: `${colors.neon}66`, borderRadius: radii.xl, borderWidth: 1, overflow: "hidden" }}
      >
        <View
          style={{
            backgroundColor: isLight ? "rgba(255,255,255,.58)" : "rgba(4,10,6,.70)",
            gap: spacing.md,
            padding: spacing.lg
          }}
        >
          <Text style={{ ...typography.footnote, color: colors.neon, fontWeight: "900" }}>{t("home.nextMatch.eyebrow")}</Text>
          <Text style={{ ...typography.title, color: isLight ? colors.textPrimary : "#fff", fontSize: 29 }}>
            {date.toLocaleDateString(lang, { weekday: "long", day: "numeric", month: "short" })} ·{" "}
            {proposal.reservationTime.replace("-", "–")}
          </Text>
          <Text style={{ ...typography.body, color: isLight ? colors.textSecondary : "rgba(255,255,255,.8)" }}>
            {club.name} · {t("common.court").replace("{court}", String(proposal.court))}
          </Text>
          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
            <Avatar name={player?.name ?? t("home.avatarFallback")} photoURL={player?.photoURL} size={42} />
            <Text style={{ ...typography.caption, color: isLight ? colors.textPrimary : "#fff", flex: 1 }}>
              {t("home.nextMatch.confirmed")}
            </Text>
            <Pressable
              onPress={() => openInWaze(club.latitude, club.longitude, club.name)}
              style={{
                alignItems: "center",
                backgroundColor: "rgba(0,160,227,0.14)",
                borderColor: "rgba(0,168,232,0.5)",
                borderRadius: radii.pill,
                borderWidth: 1,
                flexDirection: "row",
                gap: 8,
                height: 44,
                paddingHorizontal: 14
              }}
            >
              <WazeLogo size={24} variant="brand" />
              <Text style={{ ...typography.caption, color: colors.textPrimary, fontWeight: "800" }}>{t("common.directions")}</Text>
            </Pressable>
          </View>
        </View>
      </ImageBackground>
    </Animated.View>
  );
}

/**
 * Empuje temporal de crecimiento: la comunidad todavía es pequeña, así que la
 * home invita a traer gente. El enlace apunta a la tienda del dispositivo que
 * comparte (App Store en iOS, Google Play en Android).
 */
function InviteFriendsCard({ playerName, desktop }: { playerName?: string; desktop: boolean }) {
  const { t } = useI18n();
  const name = playerName?.trim() || t("invite.fallbackName");

  return (
    <Card pad={desktop ? "xl" : "lg"} style={{ borderColor: `${colors.neon}44`, gap: spacing.sm }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
        <Icon name="users" size={22} color={colors.neon as string} />
        <Text style={{ ...typography.headline, color: colors.textPrimary, flex: 1 }}>{t("invite.title")}</Text>
      </View>
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("invite.body")}</Text>
      <PrimaryButton
        label={t("invite.message")}
        icon={<Icon name="send" size={17} color={colors.textOnBrand as string} />}
        onPress={() => void shareAppInvite(name)}
      />
    </Card>
  );
}

function SectionTitle({ title, subtitle, trailing }: { title: string; subtitle: string; trailing?: string }) { return <View style={{ gap: 2, marginTop: spacing.sm }}><View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}><Text style={{ ...typography.headline, color: colors.textPrimary }}>{title}</Text>{trailing ? <Text style={{ ...typography.footnote, color: colors.gold }}>{trailing}</Text> : null}</View><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{subtitle}</Text></View>; }
function StoryCard({ tag, title, body, image, desktop }: { tag: string; title: string; body: string; index: number; image: number; desktop: boolean }) {
  const { isLight } = useThemeMode();
  // En claro la imagen se lava sobre la card blanca: el scrim necesita más
  // fuerza para que el texto blanco siga siendo legible.
  const scrim = isLight ? "rgba(3,8,5,.84)" : "rgba(3,8,5,.76)";
  return <Card variant="interactive" style={{ flexBasis: "46%", flexGrow: 1, minWidth: 150, padding: 0 }}><ImageBackground source={image} imageStyle={{ opacity: isLight ? .92 : .82 }} style={{ height: desktop ? 280 : 150, justifyContent: "flex-end" }}><View style={{ backgroundColor: scrim, gap: desktop ? spacing.sm : 3, padding: desktop ? spacing.xl : spacing.md }}><View style={{ alignSelf: "flex-start", backgroundColor: colors.neon, borderRadius: radii.pill, paddingHorizontal: spacing.sm, paddingVertical: 3 }}><Text style={{ ...typography.footnote, color: colors.textOnBall, fontWeight: "900" }}>{tag}</Text></View><Text style={{ ...typography.subheadline, color: "#fff", fontSize: desktop ? 22 : 17 }}>{title}</Text><Text style={{ ...typography.footnote, color: "rgba(255,255,255,.78)", fontSize: desktop ? 14 : 12 }} numberOfLines={2}>{body}</Text></View></ImageBackground></Card>;
}
function CommerceCard({ name, detail, priceLabel, image, desktop }: { name: string; detail: string; priceLabel: string; image: number; desktop: boolean }) {
  const { isLight } = useThemeMode();
  const scrim = isLight ? "rgba(3,8,5,.86)" : "rgba(3,8,5,.78)";
  return <Card style={{ flexBasis: "46%", flexGrow: 1, minWidth: 150, padding: 0 }}><ImageBackground source={image} imageStyle={{ opacity: isLight ? .92 : .78 }} style={{ height: desktop ? 190 : 112, justifyContent: "flex-end" }}><View style={{ backgroundColor: scrim, padding: desktop ? spacing.lg : spacing.sm }}><Text style={{ ...typography.caption, color: "#fff", fontSize: desktop ? 18 : 13 }}>{name}</Text><Text style={{ ...typography.footnote, color: "rgba(255,255,255,.74)", fontSize: desktop ? 14 : 12 }}>{detail}</Text><Text style={{ ...typography.footnote, color: isLight ? "#DBFF63" : colors.neon, fontWeight: "800", marginTop: 3 }}>{priceLabel}</Text></View></ImageBackground></Card>;
}
function QuickAction({
  imageDark,
  imageLight,
  label,
  detail,
  desktop,
  onPress
}: {
  imageDark: number;
  imageLight: number;
  label: string;
  detail: string;
  desktop: boolean;
  onPress: () => void;
}) {
  const { isLight } = useThemeMode();
  const [hovered, setHovered] = useState(false);
  return (
    <Pressable
      onPress={onPress}
      onHoverIn={Platform.OS === "web" ? () => setHovered(true) : undefined}
      onHoverOut={Platform.OS === "web" ? () => setHovered(false) : undefined}
      style={({ pressed }) => [
        {
          alignItems: desktop ? "flex-start" : "center",
          backgroundColor: pressed
            ? colors.courtLight
            : isLight
              ? "rgba(255,255,255,0.92)"
              : "rgba(15,23,17,.88)",
          borderColor: isLight ? "rgba(55,91,42,0.16)" : colors.borderStrong,
          borderRadius: radii.lg,
          borderWidth: 1,
          boxShadow: desktop ? (isLight ? "0 12px 32px rgba(36,62,43,.09)" : shadows.card) : shadows.subtle,
          flex: 1,
          gap: spacing.sm,
          minHeight: desktop ? 160 : 100,
          minWidth: 100,
          justifyContent: "center",
          overflow: "hidden",
          padding: desktop ? spacing.xl : spacing.sm
        },
        Platform.OS === "web"
          ? ({ cursor: "pointer", transition: "box-shadow 0.2s ease, transform 0.2s ease, border-color 0.2s ease" } as object)
          : undefined,
        Platform.OS === "web" && hovered
          ? {
              borderColor: isLight ? "rgba(55,91,42,0.32)" : `${colors.neon}44`,
              boxShadow: isLight ? "0 18px 40px rgba(36,62,43,.14)" : shadows.floating,
              transform: [{ translateY: -2 }]
            }
          : undefined
      ]}
    >
      <Image
        source={isLight ? imageLight : imageDark}
        style={{
          borderRadius: radii.md,
          height: desktop ? 56 : 40,
          width: desktop ? 56 : 40
        }}
      />
      <Text style={{ ...typography.subheadline, color: colors.textPrimary, textAlign: desktop ? "left" : "center" }}>
        {label}
      </Text>
      {desktop ? <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{detail}</Text> : null}
    </Pressable>
  );
}
function CommunityStat({ icon, value, label, desktop }: { icon: IconName; value: number; label: string; desktop: boolean }) { return <View style={{ alignItems: "center", backgroundColor: colors.surfaceCourt, borderColor: desktop ? colors.border : "transparent", borderRadius: radii.md, borderWidth: desktop ? 1 : 0, flexBasis: "22%", flexGrow: 1, gap: desktop ? spacing.xs : 0, padding: desktop ? spacing.lg : spacing.sm }}><Icon name={icon} size={desktop ? 24 : 18} color={colors.neon as string} /><Text style={{ ...(desktop ? broadcast.stat : typography.headline), color: colors.textPrimary, fontSize: desktop ? 28 : 20 }}>{value}</Text><Text style={{ ...typography.footnote, color: colors.textTertiary, fontSize: desktop ? 12 : 9, textAlign: "center" }}>{label}</Text></View>; }
