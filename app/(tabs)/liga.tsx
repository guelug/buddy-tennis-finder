import * as React from "react";
import { useMemo, useState } from "react";
import { Alert, Platform, Pressable, Text, useWindowDimensions, View } from "react-native";
import { router } from "expo-router";
import Animated, { FadeIn, useAnimatedStyle, useSharedValue, withSpring } from "react-native-reanimated";
import { Card } from "@/components/card";
import { Avatar } from "@/components/avatar";
import { Chip } from "@/components/chip";
import { ConceptHero } from "@/components/concept-hero";
import { Icon } from "@/components/icon";
import { Podium } from "@/components/podium";
import { PrimaryButton } from "@/components/primary-button";
import { RankingRow } from "@/components/ranking-row";
import { SectionTitle } from "@/components/section-title";
import { CountUp } from "@/components/count-up";
import { LoadingView } from "@/components/loading-view";
import { ScreenShell } from "@/components/screen-shell";
import { WebShell } from "@/components/web/web-shell";
import {
  bgLeaguesLive,
  bgLeaguesLiveLight,
  bgRankingLive,
  bgRankingLiveLight,
  bgTeamsLive,
  bgTeamsLiveLight,
  bgTournamentsLive,
  bgTournamentsLiveLight,
  BroadcastHeader,
  GlassPanel,
  LiveBackground,
  LiveBallStage
} from "@/components/live-visuals";
import { DivisionBadge, DivisionIdentity as DivisionIdentityMark } from "@/components/division-badge";
import { buildProvisionalRankings, DIVISION_LABELS, DIVISION_META, rankingsByDivision, scopeRankingToArea, TIER_META } from "@/data/rankings";
import { currentPlayer } from "@/data/seed";
import { initialLeagues, publicLeagueForDivision, publicLeagueIdsFor, teamStandings, tournaments, type ClubLeague } from "@/data/competition-hub";
import { getClubs, getPlayer, getPlayersForArea, getValidatedRankingResults, joinPublicLeague, leavePublicLeague } from "@/lib/firestore";
import { useAuth } from "@/lib/firebase-auth";
import { useI18n } from "@/lib/i18n";
import { PURCHASES_ENABLED } from "@/lib/features";
import { broadcast, brand, colors, shadows, spacing, typography, radii, usePlatformLayout } from "@/theme";
import { Division, RankingEntry } from "@/types";

const DIVISIONS: Division[] = ["novato", "d", "c", "b", "a"];
/** Etiquetas de una letra para el stepper de divisiones del header desktop. */
const DIVISION_SHORT: Record<Division, string> = { novato: "N", d: "D", c: "C", b: "B", a: "A" };
type CompetitionMode = "individual" | "teams" | "leagues" | "tournaments";
/** El ranking se puede ver acotado a la ciudad del jugador o a nivel global. */
type RankingScope = "regional" | "global";
const DEMO_AVATARS = ["Ana Morales", "Carlos Rivera", "María Fernanda López", "Diego Castillo"];

function getCompetitionBackground(mode: CompetitionMode) {
  if (mode === "teams") return { source: bgTeamsLive, lightSource: bgTeamsLiveLight };
  if (mode === "leagues") return { source: bgLeaguesLive, lightSource: bgLeaguesLiveLight };
  if (mode === "tournaments") return { source: bgTournamentsLive, lightSource: bgTournamentsLiveLight };
  return { source: bgRankingLive, lightSource: bgRankingLiveLight };
}

export default function LigaScreen() {
  const { isWebDesktop } = usePlatformLayout();
  const rankingData = useCompetitionRankings();
  if (rankingData.loading) return <LoadingView />;
  if (rankingData.error) return <CompetitionLoadError message={rankingData.error} onRetry={rankingData.retry} />;
  const props = {
    rankings: rankingData.rankings,
    currentPlayerId: rankingData.currentPlayerId,
    currentLevel: rankingData.currentLevel,
    area: rankingData.area
  };
  return isWebDesktop ? <LigaWeb {...props} /> : <LigaNative {...props} />;
}

type RankingScreenProps = {
  rankings: Record<Division, RankingEntry[]>;
  currentPlayerId: string;
  currentLevel: Division;
  /** Ciudad y país del jugador — definen su ranking y su liga regional. */
  area: { city?: string; country?: string };
};

function LigaNative({ rankings, currentPlayerId, currentLevel, area }: RankingScreenProps) {
  const [division, setDivision] = useState<Division>(currentLevel);
  const [mode, setMode] = useState<CompetitionMode>("individual");
  const background = getCompetitionBackground(mode);
  const content = <LigaContent division={division} onDivisionChange={setDivision} mode={mode} onModeChange={setMode} rankings={rankings} currentPlayerId={currentPlayerId} currentLevel={currentLevel} area={area} />;
  return (
    <LiveBackground source={background.source} lightSource={background.lightSource} overlay={0.4}>
      <ScreenShell width="base">{content}</ScreenShell>
    </LiveBackground>
  );
}

function LigaWeb({ rankings, currentPlayerId, currentLevel, area }: RankingScreenProps) {
  const [division, setDivision] = useState<Division>(currentLevel);
  const [mode, setMode] = useState<CompetitionMode>("individual");
  const background = getCompetitionBackground(mode);
  return (
    <LiveBackground source={background.source} lightSource={background.lightSource} overlay={0.36}>
      <WebShell>
        <LigaContent division={division} onDivisionChange={setDivision} mode={mode} onModeChange={setMode} rankings={rankings} currentPlayerId={currentPlayerId} currentLevel={currentLevel} area={area} />
      </WebShell>
    </LiveBackground>
  );
}

function useCompetitionRankings() {
  const { user, isConfigured } = useAuth();
  const { t } = useI18n();
  const [rankings, setRankings] = useState<Record<Division, RankingEntry[]>>(rankingsByDivision);
  const [currentPlayerId, setCurrentPlayerId] = useState(currentPlayer.id);
  const [currentLevel, setCurrentLevel] = useState<Division>(currentPlayer.level);
  const [area, setArea] = useState<{ city?: string; country?: string }>({
    city: currentPlayer.city,
    country: currentPlayer.country
  });
  const [loading, setLoading] = useState(isConfigured);
  const [error, setError] = useState<string | null>(null);
  const [retryKey, setRetryKey] = useState(0);

  React.useEffect(() => {
    if (!isConfigured) {
      setRankings(rankingsByDivision);
      setCurrentPlayerId(currentPlayer.id);
      setCurrentLevel(currentPlayer.level);
      setArea({ city: currentPlayer.city, country: currentPlayer.country });
      setLoading(false);
      return;
    }
    let active = true;
    setLoading(true);
    setError(null);
    getPlayer(user?.uid ?? "").then((me) => Promise.all([
      getPlayersForArea(me?.city ?? currentPlayer.city),
      getClubs(),
      getValidatedRankingResults(me?.city ?? currentPlayer.city),
      Promise.resolve(me)
    ]))
      .then(([players, clubs, results, me]) => {
        if (!active) return;
        setRankings(buildProvisionalRankings(players, clubs, results));
        setCurrentPlayerId(user?.uid ?? "");
        setCurrentLevel(me?.level ?? "novato");
        setArea({ city: me?.city, country: me?.country });
      })
      .catch((reason: unknown) => {
        if (active) setError(reason instanceof Error ? reason.message : t("ranking.error.load"));
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => { active = false; };
  }, [isConfigured, retryKey, user?.uid, t]);

  return {
    rankings,
    currentPlayerId,
    currentLevel,
    area,
    loading,
    error,
    retry: () => setRetryKey((value) => value + 1)
  };
}

function CompetitionLoadError({ message, onRetry }: { message: string; onRetry: () => void }) {
  const { t } = useI18n();
  return (
    <LiveBackground source={bgRankingLive} lightSource={bgRankingLiveLight} overlay={0.4}>
      <ScreenShell>
        <Card variant="elevated">
          <View style={{ alignItems: "center", gap: spacing.md, paddingVertical: spacing.xl }}>
            <Icon name="trophy" size={36} color={colors.warning as string} />
            <Text style={{ ...typography.headline, color: colors.textPrimary, textAlign: "center" }}>{t("ranking.error.title")}</Text>
            <Text selectable style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>{message}</Text>
            <PrimaryButton label={t("common.retry")} onPress={onRetry} />
          </View>
        </Card>
      </ScreenShell>
    </LiveBackground>
  );
}

function CompetitionModeNav({ mode, onChange }: { mode: CompetitionMode; onChange: (mode: CompetitionMode) => void }) {
  const { t } = useI18n();
  const items: Array<{ id: CompetitionMode; label: string; icon: React.ComponentProps<typeof Icon>["name"] }> = [
    { id: "individual", label: t("ranking.mode.individual"), icon: "user" },
    { id: "teams", label: t("ranking.mode.teams"), icon: "users" },
    { id: "leagues", label: t("ranking.mode.leagues"), icon: "trophy" },
    { id: "tournaments", label: t("ranking.mode.tournaments"), icon: "zap" }
  ];
  // En pantallas estrechas el icono no cabe junto a etiquetas largas
  // ("Tournaments", "Turnuvalar"…) y el texto se partía en dos líneas dentro
  // de la píldora. Por debajo de 420 px mostramos solo el texto, en una línea.
  const { width } = useWindowDimensions();
  const showIcons = width >= 420;
  const labelSize = showIcons ? 13 : width < 360 ? 10.5 : 12;
  return (
    <View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.pill, borderWidth: 1, flexDirection: "row", gap: 4, padding: 4 }}>
      {items.map((item) => (
        <Pressable
          key={item.id}
          accessibilityRole="button"
          accessibilityState={{ selected: mode === item.id }}
          onPress={() => onChange(item.id)}
          style={{ alignItems: "center", backgroundColor: mode === item.id ? colors.courtLight : "transparent", borderRadius: radii.pill, flex: 1, flexDirection: "row", gap: showIcons ? spacing.xs : 0, justifyContent: "center", minHeight: 42, minWidth: 0, paddingHorizontal: showIcons ? spacing.sm : 2 }}
        >
          {showIcons ? <Icon name={item.icon} size={15} color={(mode === item.id ? colors.neon : colors.textTertiary) as string} /> : null}
          <Text
            numberOfLines={1}
            adjustsFontSizeToFit={Platform.OS !== "web"}
            minimumFontScale={0.8}
            style={{ ...typography.caption, color: mode === item.id ? colors.neon : colors.textSecondary, flexShrink: 1, fontSize: labelSize, fontWeight: "800", textAlign: "center" }}
          >
            {item.label}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}

/**
 * Selector regional/global. Muestra el nombre real de la ciudad para que el
 * jugador entienda contra quién compite, y el número de perfiles en cada
 * ámbito para que un regional vacío no parezca un error.
 */
function RankingScopeSelector({
  scope,
  onChange,
  areaLabel,
  regionalCount,
  globalCount
}: {
  scope: RankingScope;
  onChange: (scope: RankingScope) => void;
  areaLabel: string;
  regionalCount: number;
  globalCount: number;
}) {
  const { t } = useI18n();
  const options: Array<{ id: RankingScope; label: string; count: number }> = [
    { id: "regional", label: areaLabel, count: regionalCount },
    { id: "global", label: t("ranking.scope.global"), count: globalCount }
  ];
  return (
    <View style={{ gap: spacing.xs }}>
      <View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.pill, borderWidth: 1, flexDirection: "row", gap: 4, padding: 4 }}>
        {options.map((option) => (
          <Pressable
            key={option.id}
            accessibilityRole="button"
            accessibilityState={{ selected: scope === option.id }}
            onPress={() => onChange(option.id)}
            style={{ alignItems: "center", backgroundColor: scope === option.id ? colors.courtLight : "transparent", borderRadius: radii.pill, flex: 1, justifyContent: "center", minHeight: 40, minWidth: 0, paddingHorizontal: spacing.sm }}
          >
            <Text
              numberOfLines={1}
              style={{ ...typography.caption, color: scope === option.id ? colors.neon : colors.textSecondary, fontSize: 12, fontWeight: "800" }}
            >
              {option.label} · {option.count}
            </Text>
          </Pressable>
        ))}
      </View>
      {scope === "regional" && regionalCount === 0 ? (
        <Text style={{ ...typography.footnote, color: colors.textTertiary }}>{t("ranking.scope.emptyRegional")}</Text>
      ) : null}
    </View>
  );
}

function DivisionSelector({ division, onChange }: { division: Division; onChange: (division: Division) => void }) {
  return (
    <View style={{ alignItems: "center", flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
      {DIVISIONS.map((item) => {
        const active = item === division;
        const meta = DIVISION_META[item];
        return (
          <Pressable
            key={item}
            onPress={() => onChange(item)}
            accessibilityRole="button"
            accessibilityState={{ selected: active }}
            style={{
              alignItems: "center",
              backgroundColor: active ? `${meta.accent}22` : colors.surface,
              borderColor: active ? `${meta.accent}88` : colors.border,
              borderRadius: radii.pill,
              borderWidth: 1,
              flexDirection: "row",
              gap: 8,
              height: 44,
              paddingHorizontal: 10,
              paddingRight: 14
            }}
          >
            <DivisionBadge division={item} size={28} active={active} />
            <Text style={{ ...typography.caption, color: active ? meta.accent : colors.textSecondary, fontWeight: "900" }}>
              {DIVISION_LABELS[item]}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

function CompetitionSection({ mode, division, onDivisionChange, userLevel, city }: { mode: Exclude<CompetitionMode, "individual">; division: Division; onDivisionChange: (division: Division) => void; userLevel: Division; city?: string }) {
  const { t } = useI18n();
  return (
    <View style={{ gap: spacing.lg }}>
      <BroadcastHeader
        kicker={t("ranking.kicker")}
        title={mode === "teams" ? t("ranking.teams.title") : mode === "leagues" ? t("ranking.leagues.title") : t("ranking.tournaments.title")}
        subtitle={mode === "teams" ? t("ranking.teams.subtitle") : mode === "leagues" ? t("ranking.leagues.subtitle") : t("ranking.tournaments.subtitle")}
        trailing={<DivisionSelector division={division} onChange={onDivisionChange} />}
      />
      {/* Las ligas públicas SÍ son reales: el jugador puede inscribirse en la de
          su rango. El resto (equipos/torneos) es preview. */}
      {mode === "leagues" ? <PublicLeaguePanel userLevel={userLevel} city={city} /> : null}
      <Card style={{ backgroundColor: colors.infoBg, borderColor: `${colors.info}44` }}>
        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
          <Icon name="zap" size={20} color={colors.info as string} />
          <View style={{ flex: 1 }}>
            <Text style={{ ...typography.caption, color: colors.textPrimary }}>{t("ranking.preview.title")}</Text>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("ranking.preview.body")}</Text>
          </View>
        </View>
      </Card>
      {mode === "teams" ? <TeamStandings division={division} /> : mode === "leagues" ? <LeagueManager division={division} /> : <TournamentGrid division={division} />}
    </View>
  );
}

/**
 * Liga pública del rango del jugador: siempre abierta y gratis. La inscripción
 * se persiste en el propio perfil (`publicLeagues`). En modo demo (sin Firebase)
 * el estado es local para poder ver el flujo.
 */
function PublicLeaguePanel({ userLevel, city }: { userLevel: Division; city?: string }) {
  const { t } = useI18n();
  const { user, isConfigured } = useAuth();
  const league = publicLeagueForDivision(userLevel, city);
  // Los perfiles inscritos antes de separar las ligas por ciudad guardaron el
  // id sin sufijo; se aceptan ambos para no perder esas inscripciones.
  const acceptedIds = publicLeagueIdsFor(userLevel, city);
  const [joined, setJoined] = useState(false);
  const [busy, setBusy] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);

  React.useEffect(() => {
    let active = true;
    if (!isConfigured || !user) return;
    getPlayer(user.uid)
      .then((player) => {
        if (active && player) {
          setJoined(Boolean(player.publicLeagues?.some((id) => acceptedIds.includes(id))));
        }
      })
      .catch(() => {});
    return () => { active = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConfigured, user, league.id]);

  const openLeague = () => router.push(`/league/${league.id}` as never);

  const toggle = async () => {
    const next = !joined;
    setFeedback(null);
    setJoined(next);
    if (!isConfigured || !user) {
      // Modo demo: no hay nada que persistir, pero el flujo debe llevar a la
      // misma vista de liga para poder revisarlo sin backend.
      if (next) openLeague();
      return;
    }
    setBusy(true);
    try {
      const write = next ? joinPublicLeague(user.uid, league.id) : leavePublicLeague(user.uid, league.id);
      await Promise.race([
        write,
        new Promise<never>((_, reject) => setTimeout(() => reject(new Error(t("league.inviteError"))), 12_000))
      ]);
      setFeedback(next ? t("ranking.publicLeague.joined") : null);
      // Antes, inscribirse solo cambiaba la etiqueta del botón y parecía que
      // no había pasado nada. Ahora se abre la liga con inscritos y reglas.
      if (next) openLeague();
    } catch (error) {
      setJoined(!next);
      const message = error instanceof Error ? error.message : t("league.inviteError");
      setFeedback(message);
      Alert.alert(t("league.joinError"), message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card variant="premium" style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, boxShadow: shadows.courtGlow }}>
      <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
        <Text style={{ ...broadcast.jersey, color: colors.neon, fontSize: 12, letterSpacing: 1.6 }}>{t("ranking.publicLeague.eyebrow")}</Text>
        <DivisionBadge division={userLevel} size={26} active />
      </View>
      <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 22, marginTop: 4 }}>{league.name}</Text>
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("ranking.publicLeague.body")}</Text>
      <View style={{ gap: spacing.sm, marginTop: spacing.sm }}>
        {joined ? (
          <PrimaryButton
            label={t("ranking.publicLeague.view")}
            onPress={openLeague}
            icon={<Icon name="trophy" size={16} color={colors.textOnBrand as string} />}
          />
        ) : null}
        <PrimaryButton
          label={busy ? t("ranking.publicLeague.joining") : joined ? t("ranking.publicLeague.leave") : t("ranking.publicLeague.join")}
          variant={joined ? "outline" : "solid"}
          onPress={toggle}
          disabled={busy}
          icon={joined ? <Icon name="check-badge" size={16} color={colors.court as string} /> : undefined}
        />
      </View>
      {joined ? (
        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs, marginTop: spacing.xs }}>
          <Icon name="check-badge" size={14} color={colors.neon as string} />
          <Text style={{ ...typography.footnote, color: colors.neon, fontWeight: "800" }}>{t("ranking.publicLeague.joined")}</Text>
        </View>
      ) : null}
      {feedback ? <Text selectable style={{ ...typography.footnote, color: joined ? colors.neon : colors.textSecondary, marginTop: spacing.xs }}>{feedback}</Text> : null}
      <Text style={{ ...typography.footnote, color: colors.textTertiary, marginTop: spacing.xs }}>{t("ranking.publicLeague.private")}</Text>
    </Card>
  );
}

function TeamStandings({ division }: { division: Division }) {
  const { t } = useI18n();
  const rows = teamStandings.filter((team) => team.division === division).sort((a, b) => b.points - a.points);
  return (
    <GlassPanel pad="md">
      <View style={{ flexDirection: "row", gap: spacing.sm, paddingHorizontal: spacing.sm, paddingBottom: spacing.sm }}>
        <Text style={{ ...typography.footnote, color: colors.textTertiary, width: 28 }}>#</Text>
        <Text style={{ ...typography.footnote, color: colors.textTertiary, flex: 1 }}>{t("ranking.table.team")}</Text>
        <Text style={{ ...typography.footnote, color: colors.textTertiary, width: 70, textAlign: "center" }}>{t("ranking.table.wl")}</Text>
        <Text style={{ ...typography.footnote, color: colors.textTertiary, width: 72, textAlign: "right" }}>{t("ranking.table.points")}</Text>
      </View>
      {rows.length ? rows.map((team, index) => (
        <View key={team.id} style={{ alignItems: "center", borderTopColor: colors.border, borderTopWidth: 1, flexDirection: "row", gap: spacing.sm, padding: spacing.sm }}>
          <Text style={{ ...broadcast.stat, color: index === 0 ? colors.neon : colors.textTertiary, width: 28 }}>{index + 1}</Text>
          <View style={{ flex: 1 }}>
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{team.name}</Text>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{team.members.join(" + ")} · Sets {team.setsFor}-{team.setsAgainst}</Text>
          </View>
          <Text style={{ ...typography.caption, color: colors.textSecondary, width: 70, textAlign: "center" }}>{team.wins}–{team.losses}</Text>
          <Text style={{ ...broadcast.stat, color: colors.neon, width: 72, textAlign: "right" }}>{team.points}</Text>
        </View>
      )) : <EmptyCompetition text={t("ranking.empty.teams")} />}
    </GlassPanel>
  );
}

function LeagueManager({ division }: { division: Division }) {
  const { t } = useI18n();
  const visible = initialLeagues.filter((league) => league.division === division);

  return (
    <View style={{ gap: spacing.lg }}>
      <GlassPanel pad="md">
        <View style={{ alignItems: "center", flexDirection: "row", flexWrap: "wrap", gap: spacing.md, justifyContent: "space-between" }}>
          <View style={{ flex: 1, minWidth: 220 }}>
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("ranking.privateLeagues.title")}</Text>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("ranking.privateLeagues.body")}</Text>
          </View>
          {PURCHASES_ENABLED
            ? <PrimaryButton label={t("profile.privateLeagues")} fullWidth={false} onPress={() => router.push("/private-leagues" as never)} style={{ minWidth: 170 }} />
            : <PrimaryButton label={t("ranking.comingSoon")} fullWidth={false} disabled onPress={() => {}} style={{ minWidth: 170 }} />}
        </View>
      </GlassPanel>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
        {visible.length ? visible.map((league) => <LeagueCard key={league.id} league={league} />) : <EmptyCompetition text={t("ranking.empty.leagues")} />}
      </View>
    </View>
  );
}

function LeagueCard({ league }: { league: ClubLeague }) {
  const { t } = useI18n();
  const pct = Math.min(100, (league.participants / league.capacity) * 100);
  return <GlassPanel pad="md" style={{ flexBasis: 300, flexGrow: 1 }}><View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}><Text style={{ ...broadcast.jersey, color: colors.neon }}>{league.season}</Text>{league.demoParticipants ? <View style={{ backgroundColor: colors.courtLight, borderRadius: radii.pill, paddingHorizontal: spacing.sm, paddingVertical: 3 }}><Text style={{ ...typography.footnote, color: colors.court, fontWeight: "800" }}>{t("ranking.demoView")}</Text></View> : null}</View><Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 22 }}>{league.name}</Text>{league.demoParticipants ? <DemoAvatarStack /> : null}<Text style={{ ...typography.footnote, color: colors.textSecondary }}>{league.format === "doubles" ? t("ranking.league.doubles") : t("ranking.mode.individual")} · {t("ranking.league.enrolled").replace("{participants}", String(league.participants)).replace("{capacity}", String(league.capacity))}</Text><ProgressBar pct={pct} /><InfoChip icon="check-badge" label={t("ranking.status")} value={league.status === "open" ? t("ranking.leagueStatus.open") : league.status === "full" ? t("ranking.leagueStatus.full") : league.status === "playing" ? t("ranking.leagueStatus.playing") : t("ranking.leagueStatus.closed")} /></GlassPanel>;
}

function TournamentGrid({ division }: { division: Division }) {
  const { t } = useI18n();
  const visible = tournaments.filter((item) => item.division === division);
  return <View style={{ gap: spacing.md }}><Text style={{ ...typography.footnote, color: colors.textTertiary }}>{t("ranking.tournaments.previewNote")}</Text><View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>{visible.length ? visible.map((item) => <GlassPanel key={item.id} pad="md" style={{ flexBasis: 290, flexGrow: 1 }}><View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}><Text style={{ ...broadcast.jersey, color: colors.gold }}>{t("ranking.tournament.kicker")}</Text>{item.demoEntrants ? <View style={{ backgroundColor: colors.goldSoft, borderRadius: radii.pill, paddingHorizontal: spacing.sm, paddingVertical: 3 }}><Text style={{ ...typography.footnote, color: colors.gold, fontWeight: "800" }}>{t("ranking.demoView")}</Text></View> : null}</View><Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 22 }}>{item.name}</Text>{item.demoEntrants ? <DemoAvatarStack /> : null}<Text style={{ ...typography.caption, color: colors.neon }}>{t("ranking.tournament.format").replace("{round}", item.round)}</Text><Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("ranking.tournament.capacity").replace("{division}", DIVISION_LABELS[item.division]).replace("{capacity}", String(item.capacity))}</Text><ProgressBar pct={0} /><PrimaryButton label={t("ranking.comingSoon")} disabled onPress={() => {}} /></GlassPanel>) : <EmptyCompetition text={t("ranking.empty.tournaments")} />}</View></View>;
}

function DemoAvatarStack() {
  const { t } = useI18n();
  return <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm, marginBottom: spacing.xs, marginTop: spacing.xs }}><View style={{ flexDirection: "row" }}>{DEMO_AVATARS.map((name, index) => <View key={name} style={{ borderColor: colors.surface, borderRadius: 18, borderWidth: 2, marginLeft: index === 0 ? 0 : -9 }}><Avatar name={name} size={30} /></View>)}</View><Text style={{ ...typography.footnote, color: colors.textTertiary }}>{t("ranking.demoProfiles")}</Text></View>;
}

function EmptyCompetition({ text }: { text: string }) {
  return <Card style={{ flex: 1, minWidth: 280 }}><Text style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>{text}</Text></Card>;
}

function ProgressBar({ pct }: { pct: number }) {
  const width = useSharedValue(0);

  React.useEffect(() => {
    width.value = withSpring(pct / 100, { damping: 14, stiffness: 180 });
  }, [pct, width]);

  const style = useAnimatedStyle(() => ({
    width: `${width.value * 100}%`
  }));

  return (
    <View
      style={{
        backgroundColor: colors.surfaceElevated,
        borderRadius: radii.pill,
        height: 8,
        marginTop: spacing.sm,
        overflow: "hidden"
      }}
    >
      <Animated.View
        style={[
          {
            backgroundColor: colors.gold,
            borderRadius: radii.pill,
            height: 8
          },
          style
        ]}
      />
    </View>
  );
}

function LigaContent({
  division,
  onDivisionChange,
  mode,
  onModeChange,
  rankings,
  currentPlayerId,
  currentLevel,
  area
}: {
  division: Division;
  onDivisionChange: (d: Division) => void;
  mode: CompetitionMode;
  onModeChange: (mode: CompetitionMode) => void;
  rankings: Record<Division, RankingEntry[]>;
  currentPlayerId: string;
  currentLevel: Division;
  area: { city?: string; country?: string };
}) {
  const { isWebDesktop } = usePlatformLayout();
  const { t } = useI18n();
  // Por defecto el jugador ve SU región: es su competición real. El global
  // queda a un toque para dar contexto mientras la base de usuarios crece.
  const [scope, setScope] = useState<RankingScope>("regional");
  const allEntries = rankings[division] ?? [];
  const regionalEntries = useMemo(
    () => scopeRankingToArea(allEntries, area.city, area.country),
    [allEntries, area.city, area.country]
  );
  const entries = scope === "regional" ? regionalEntries : allEntries;
  const divisionMeta = DIVISION_META[division];
  const podium = entries.slice(0, 3);
  const rest = entries.slice(3);
  const you = entries.find((entry) => entry.playerId === currentPlayerId);
  const leader = entries[0];
  const liveMoves = entries.slice(0, 5).map((entry) => ({
    entry,
    delta: 0
  }));

  const challenge = useMemo(() => {
    if (!you || you.rank === 1) return null;
    const above = entries.find((e) => e.rank === you.rank - 1);
    if (!above) return null;
    const gap = above.points - you.points;
    const pct = above.points > 0 ? Math.min(100, (you.points / above.points) * 100) : 100;
    return { above, gap, pct };
  }, [you, entries]);

  const modeNav = <CompetitionModeNav mode={mode} onChange={onModeChange} />;
  const areaLabel = area.city || area.country || t("ranking.scope.regional");
  const scopeSelector = (
    <RankingScopeSelector
      scope={scope}
      onChange={setScope}
      areaLabel={areaLabel}
      regionalCount={regionalEntries.length}
      globalCount={allEntries.length}
    />
  );

  if (mode !== "individual") {
    return (
      <View style={{ gap: spacing.lg }}>
        {modeNav}
        <CompetitionSection mode={mode} division={division} onDivisionChange={onDivisionChange} userLevel={currentLevel} city={area.city} />
      </View>
    );
  }

  if (isWebDesktop) {
    return (
      <View style={{ gap: spacing.lg }}>
        {modeNav}
        {scopeSelector}
        <PublicLeaguePanel userLevel={currentLevel} city={area.city} />
        <RankingWebDashboard
          division={division}
          onDivisionChange={onDivisionChange}
          entries={entries}
          podium={podium}
          you={you}
          leader={leader}
          liveMoves={liveMoves}
          challenge={challenge}
          currentPlayerId={currentPlayerId}
        />
      </View>
    );
  }

  return (
    <View style={{ gap: spacing.lg }}>
      {modeNav}
      <ConceptHero
        kicker={t("ranking.hero.kicker").replace("{circuit}", divisionMeta.circuit)}
        title={t("ranking.hero.title").replace("{division}", DIVISION_LABELS[division])}
        body={t("ranking.hero.body").replace("{motto}", divisionMeta.motto).replace("{proof}", divisionMeta.proof)}
        centerLabel={`#${you?.rank ?? "-"}`}
        metrics={[
          { icon: "trophy", label: t("ranking.metric.position"), value: `#${you?.rank ?? "-"}` },
          { icon: "zap", label: t("ranking.table.points"), value: you?.points ?? 0 },
          { icon: "check-badge", label: t("ranking.metric.activeProfiles"), value: entries.length }
        ]}
        chips={[
          { icon: "trophy", label: t("ranking.leader"), value: leader?.playerName ?? t("ranking.noData") },
          { icon: "check-badge", label: t("ranking.circuit"), value: divisionMeta.circuit },
          { icon: "zap", label: t("ranking.status"), value: t("ranking.statusProvisional") }
        ]}
      />

      <DivisionSelector division={division} onChange={onDivisionChange} />

      {scopeSelector}

      {/* La liga pública del rango se ofrecía solo dentro de la pestaña
          "Ligas" y pasaba desapercibida; aquí es lo primero que se ve. */}
      <PublicLeaguePanel userLevel={currentLevel} city={area.city} />

      <LiveMovementStrip moves={liveMoves} />

      {you ? (
        <Animated.View entering={FadeIn.springify()}>
          <Card
            variant="plain"
            style={{
              backgroundColor: colors.courtLight,
              borderColor: `${colors.neon}45`,
              boxShadow: shadows.courtGlow
            }}
          >
            <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
              <View>
                <Text style={{ ...broadcast.jersey, color: colors.neon, fontSize: 12, letterSpacing: 1.6 }}>
                  {t("ranking.livePosition")}
                </Text>
                <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 22, marginTop: 2 }}>
                  {t("ranking.livePositionIn").replace("{rank}", String(you.rank)).replace("{division}", DIVISION_LABELS[division])}
                </Text>
              </View>
              <CountUp
                value={you.points}
                suffix=" pts"
                style={{ ...typography.metric, color: colors.court, fontSize: 24, fontVariant: ["tabular-nums"] }}
              />
            </View>
          </Card>
        </Animated.View>
      ) : null}

      {challenge ? (
        <RankingChaseCard
          target={challenge.above.playerName}
          gap={challenge.gap}
          rank={challenge.above.rank}
          pct={challenge.pct}
        />
      ) : null}

      <SectionTitle title={t("ranking.podium")} />
      <Podium entries={podium} />

      <SectionTitle
        title={t("ranking.fullStandings")}
        actionLabel={t("ranking.findRival")}
        onAction={() => router.push("/")}
      />

      <Card pad="base" gap="xs" style={{ overflow: "hidden", padding: 0 }}>
        {rest.map((entry, index) => (
          <RankingRow
            key={entry.playerId}
            entry={entry}
            highlight={entry.playerId === currentPlayerId}
            index={index}
          />
        ))}
      </Card>
    </View>
  );
}

function RankingWebDashboard({
  division,
  onDivisionChange,
  entries,
  podium,
  you,
  leader,
  liveMoves,
  challenge,
  currentPlayerId
}: {
  division: Division;
  onDivisionChange: (d: Division) => void;
  entries: RankingEntry[];
  podium: RankingEntry[];
  you: RankingEntry | null | undefined;
  leader: RankingEntry | undefined;
  liveMoves: Array<{ entry: RankingEntry; delta: number }>;
  challenge: { above: RankingEntry; gap: number; pct: number } | null;
  currentPlayerId: string;
}) {
  const { t } = useI18n();
  const divisionMeta = DIVISION_META[division];
  return (
    <View style={{ gap: spacing.lg }}>
      <BroadcastHeader
        kicker={t("ranking.hero.kicker").replace("{circuit}", divisionMeta.circuit)}
        title={t("ranking.hero.title").replace("{division}", DIVISION_LABELS[division])}
        subtitle={t("ranking.web.subtitle").replace("{motto}", divisionMeta.motto).replace("{proof}", divisionMeta.proof)}
        trailing={
          <View style={{ alignItems: "flex-end", gap: spacing.sm }}>
          <DivisionIdentity division={division} />
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs, justifyContent: "flex-end" }}>
            {DIVISIONS.map((d) => (
              <Chip key={d} label={DIVISION_SHORT[d]} active={division === d} onPress={() => onDivisionChange(d)} />
            ))}
          </View>
          </View>
        }
      />

      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.lg, alignItems: "stretch" }}>
        <GlassPanel style={{ flex: 1.35, minWidth: 320, minHeight: 330 }}>
          <View style={{ alignItems: "center", flex: 1, flexDirection: "row", flexWrap: "wrap", gap: spacing.lg, justifyContent: "center" }}>
            <View style={{ alignSelf: "stretch", flexBasis: 260, flexGrow: 1, gap: spacing.lg, justifyContent: "space-between", minWidth: 0 }}>
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
                <RankingMetric label={t("ranking.metric.position")} value={`#${you?.rank ?? "-"}`} detail={`${you?.points ?? 0} pts`} />
                <RankingMetric label={t("ranking.metric.basePoints")} value={you?.points ?? 0} detail={t("ranking.metric.provisional")} />
                <RankingMetric
                  label={t("ranking.metric.balance")}
                  value={you && you.wins + you.losses > 0 ? `${you.wins}–${you.losses}` : "—"}
                  detail={you?.streak ? t("ranking.metric.streakOf").replace("{n}", String(you.streak)) : t("ranking.metric.winsLosses")}
                />
              </View>
              <View style={{ gap: spacing.xs }}>
                <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
                  <Text style={{ ...typography.footnote, color: colors.textTertiary, fontWeight: "800", letterSpacing: 0.8 }}>
                    {t("ranking.chase.eyebrow")}
                  </Text>
                  <Text style={{ ...typography.footnote, color: colors.neon, fontWeight: "800" }}>
                    {challenge ? t("ranking.chase.gap").replace("{gap}", String(challenge.gap)) : t("ranking.chase.noRival")}
                  </Text>
                </View>
                <Text style={{ ...typography.caption, color: colors.textPrimary }}>
                  {challenge
                    ? t("ranking.chase.target").replace("{name}", challenge.above.playerName).replace("{rank}", String(challenge.above.rank))
                    : t("ranking.chase.leader")}
                </Text>
                <ProgressBar pct={challenge?.pct ?? 100} />
              </View>
              <View style={{ flexDirection: "row", gap: spacing.sm, flexWrap: "wrap" }}>
                <InfoChip icon="trophy" label={t("ranking.leader")} value={leader?.playerName ?? t("ranking.noData")} />
                <InfoChip icon="check-badge" label={t("ranking.rule")} value={t("ranking.ruleValue")} />
              </View>
            </View>
            <LiveBallStage label={`#${you?.rank ?? "-"}`} size={150} />
          </View>
        </GlassPanel>

        <GlassPanel style={{ flex: 0.85, minWidth: 280, minHeight: 330 }}>
          <View style={{ flex: 1, gap: spacing.md, justifyContent: "space-between" }}>
            <View style={{ gap: spacing.sm }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary, marginBottom: spacing.xs }}>{t("ranking.featured")}</Text>
              {liveMoves.slice(0, 4).map(({ entry }) => {
                const total = entry.wins + entry.losses;
                return (
                  <View
                    key={entry.playerId}
                    style={{
                      alignItems: "center",
                      borderBottomColor: colors.border,
                      borderBottomWidth: 1,
                      flexDirection: "row",
                      gap: spacing.sm,
                      paddingBottom: spacing.sm
                    }}
                  >
                    <View
                      style={{
                        alignItems: "center",
                        backgroundColor: colors.courtLight,
                        borderRadius: radii.pill,
                        height: 32,
                        justifyContent: "center",
                        width: 32
                      }}
                    >
                      <Text style={{ ...typography.caption, color: colors.neon }}>{entry.rank}</Text>
                    </View>
                    <View style={{ flex: 1, minWidth: 0 }}>
                      <Text numberOfLines={1} style={{ ...typography.caption, color: colors.textPrimary }}>{entry.playerName}</Text>
                      <Text numberOfLines={1} style={{ ...typography.footnote, color: colors.textSecondary }}>
                        {total ? t("ranking.featured.line").replace("{wins}", String(entry.wins)).replace("{losses}", String(entry.losses)).replace("{streak}", String(entry.streak || 0)) : t("ranking.featured.activeProfile")}
                      </Text>
                    </View>
                    <Text style={{ ...broadcast.jersey, color: colors.neon }}>
                      {t("ranking.pointsBase").replace("{points}", String(entry.points))}
                    </Text>
                  </View>
                );
              })}
            </View>
            <View style={{ borderTopColor: colors.border, borderTopWidth: 1, paddingTop: spacing.sm }}>
              <Text style={{ ...typography.footnote, color: colors.textTertiary }}>
                {t("ranking.featured.note")}
              </Text>
            </View>
          </View>
        </GlassPanel>
      </View>

      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.lg, alignItems: "flex-start" }}>
        <View style={{ flex: 1, minWidth: 320, gap: spacing.lg }}>
          {podium.length ? (
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md, justifyContent: "center" }}>
              {podium.map((entry) => (
                <DesktopPodiumCard key={entry.playerId} entry={entry} highlight={entry.playerId === currentPlayerId} />
              ))}
            </View>
          ) : null}

          <GlassPanel pad="md">
            <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between", marginBottom: spacing.md }}>
              <View style={{ flex: 1, minWidth: 0 }}>
                <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("ranking.hero.title").replace("{division}", DIVISION_LABELS[division])}</Text>
                <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("ranking.table.subtitle")}</Text>
              </View>
              <View style={{ backgroundColor: colors.courtLight, borderRadius: radii.pill, paddingHorizontal: spacing.md, paddingVertical: spacing.xs }}>
                <Text style={{ ...typography.caption, color: colors.neon }}>{t("ranking.table.profiles").replace("{count}", String(entries.length))}</Text>
              </View>
            </View>
            <RankingTable entries={entries} currentPlayerId={currentPlayerId} />
          </GlassPanel>
        </View>

        <View style={{ width: 320, flexShrink: 0, flexGrow: 0, gap: spacing.lg }}>
          <GlassPanel pad="md">
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("ranking.competitive.title")}</Text>
            <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14 }}>
              {t("ranking.competitive.body")}
            </Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
              <InfoChip icon="check-badge" label={t("ranking.status")} value="Beta" />
              <InfoChip icon="trophy" label={t("ranking.circuit")} value={divisionMeta.circuit} />
            </View>
          </GlassPanel>
        </View>
      </View>
    </View>
  );
}

/**
 * Card de podio desktop: medalla oro/plata/bronce, avatar y puntos en
 * tipografía broadcast. Ancho acotado para que con 1-2 jugadores la fila
 * no se estire feo; con 3 rellena el espacio de forma pareja.
 */
function DesktopPodiumCard({ entry, highlight }: { entry: RankingEntry; highlight: boolean }) {
  const { t } = useI18n();
  const isFirst = entry.rank === 1;
  const medalColor = isFirst ? brand.gold : entry.rank === 2 ? brand.silver : brand.bronze;
  return (
    <GlassPanel
      pad="md"
      style={{
        alignItems: "center",
        borderColor: isFirst ? `${colors.gold}88` : colors.borderStrong,
        boxShadow: isFirst ? shadows.glowGold : shadows.card,
        flexBasis: 180,
        flexGrow: 1,
        gap: spacing.xs,
        maxWidth: 250
      }}
    >
      <View
        style={{
          alignItems: "center",
          backgroundColor: medalColor,
          borderRadius: radii.pill,
          boxShadow: isFirst ? "0 4px 14px -2px rgba(245,197,66,0.5)" : undefined,
          height: 30,
          justifyContent: "center",
          width: 30
        }}
      >
        <Text style={{ color: isFirst ? "#231800" : "#FFFFFF", fontSize: 13, fontWeight: "900" }}>
          {isFirst ? "👑" : entry.rank}
        </Text>
      </View>
      <Avatar name={entry.playerName} size={isFirst ? 56 : 48} />
      <Text numberOfLines={1} style={{ ...typography.subheadline, color: colors.textPrimary, textAlign: "center" }}>
        {entry.playerName}{highlight ? t("ranking.youSuffix") : ""}
      </Text>
      <Text numberOfLines={1} style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>
        {entry.clubName ?? t("ranking.clubTbd")}
      </Text>
      <Text style={{ ...broadcast.stat, color: colors.court, fontVariant: ["tabular-nums"] }}>
        {entry.points} pts
      </Text>
    </GlassPanel>
  );
}

const TABLE_COL = { rank: 44, result: 62, streak: 62, points: 84 };

/**
 * Tabla de clasificación desktop: filas completas con club, balance V–D,
 * racha y puntos. Una tabla llena bien el ancho con cualquier número de
 * jugadores (las tiles sueltas quedaban feas en divisiones con pocos).
 */
function RankingTable({ entries, currentPlayerId }: { entries: RankingEntry[]; currentPlayerId: string }) {
  const { t } = useI18n();
  if (!entries.length) {
    return (
      <Text style={{ ...typography.body, color: colors.textSecondary, paddingVertical: spacing.lg, textAlign: "center" }}>
        {t("ranking.empty.division")}
      </Text>
    );
  }
  const headerCell = {
    ...typography.footnote,
    color: colors.textTertiary,
    fontSize: 11,
    fontWeight: "800" as const,
    letterSpacing: 0.8,
    textTransform: "uppercase" as const
  };
  return (
    <View style={{ borderColor: colors.border, borderRadius: radii.md, borderWidth: 1, overflow: "hidden" }}>
      <View
        style={{
          alignItems: "center",
          backgroundColor: colors.surfaceElevated,
          borderBottomColor: colors.border,
          borderBottomWidth: 1,
          flexDirection: "row",
          gap: spacing.sm,
          paddingHorizontal: spacing.md,
          paddingVertical: spacing.sm
        }}
      >
        <Text style={[headerCell, { textAlign: "center", width: TABLE_COL.rank }]}>#</Text>
        <Text style={[headerCell, { flex: 1 }]}>{t("ranking.table.player")}</Text>
        <Text style={[headerCell, { textAlign: "center", width: TABLE_COL.result }]}>{t("ranking.table.wl")}</Text>
        <Text style={[headerCell, { textAlign: "center", width: TABLE_COL.streak }]}>{t("ranking.table.streak")}</Text>
        <Text style={[headerCell, { textAlign: "right", width: TABLE_COL.points }]}>{t("ranking.table.points")}</Text>
      </View>
      {entries.map((entry, index) => (
        <RankingTableRow
          key={entry.playerId}
          entry={entry}
          highlight={entry.playerId === currentPlayerId}
          last={index === entries.length - 1}
        />
      ))}
    </View>
  );
}

function RankingTableRow({ entry, highlight, last }: { entry: RankingEntry; highlight: boolean; last: boolean }) {
  const { t } = useI18n();
  const [hovered, setHovered] = useState(false);
  const total = entry.wins + entry.losses;
  const tierColor = TIER_META[entry.tier].color;
  return (
    <Pressable
      onHoverIn={Platform.OS === "web" ? () => setHovered(true) : undefined}
      onHoverOut={Platform.OS === "web" ? () => setHovered(false) : undefined}
      style={{
        alignItems: "center",
        backgroundColor: highlight ? colors.courtLight : hovered ? colors.surfaceElevated : "transparent",
        borderBottomColor: colors.border,
        borderBottomWidth: last ? 0 : 1,
        flexDirection: "row",
        gap: spacing.sm,
        paddingHorizontal: spacing.md,
        paddingVertical: 10
      }}
    >
      <Text
        style={{
          ...broadcast.stat,
          color: entry.rank <= 3 ? tierColor : colors.textTertiary,
          fontSize: 18,
          fontVariant: ["tabular-nums"],
          textAlign: "center",
          width: TABLE_COL.rank
        }}
      >
        {entry.rank}
      </Text>
      <View style={{ alignItems: "center", flex: 1, flexDirection: "row", gap: spacing.sm, minWidth: 0 }}>
        <Avatar name={entry.playerName} size={32} />
        <View style={{ flex: 1, minWidth: 0 }}>
          <Text numberOfLines={1} style={{ ...typography.caption, color: colors.textPrimary, fontWeight: "800" }}>
            {entry.playerName}{highlight ? t("ranking.youSuffix") : ""}
          </Text>
          <Text numberOfLines={1} style={{ ...typography.footnote, color: colors.textTertiary }}>
            {entry.clubName ?? t("ranking.clubTbd")}
          </Text>
        </View>
        {entry.isDemo ? (
          <View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.pill, borderWidth: 1, paddingHorizontal: 7, paddingVertical: 3 }}>
            <Text style={{ ...typography.footnote, color: colors.textTertiary, fontSize: 9, fontWeight: "800" }}>{t("ranking.demoBadge")}</Text>
          </View>
        ) : null}
      </View>
      <Text style={{ ...typography.caption, color: colors.textSecondary, fontVariant: ["tabular-nums"], textAlign: "center", width: TABLE_COL.result }}>
        {total ? `${entry.wins}–${entry.losses}` : "—"}
      </Text>
      <Text style={{ ...typography.caption, color: colors.textSecondary, fontVariant: ["tabular-nums"], textAlign: "center", width: TABLE_COL.streak }}>
        {entry.streak || "—"}
      </Text>
      <Text
        style={{
          ...broadcast.stat,
          color: colors.court,
          fontSize: 18,
          fontVariant: ["tabular-nums"],
          textAlign: "right",
          width: TABLE_COL.points
        }}
      >
        {entry.points}
      </Text>
    </Pressable>
  );
}

function DivisionIdentity({ division }: { division: Division }) {
  return <DivisionIdentityMark division={division} />;
}

function RankingMetric({ label, value, detail }: { label: string; value: string | number; detail: string }) {
  return (
    <View
      style={{
        backgroundColor: colors.surfaceCourt,
        borderColor: colors.border,
        borderRadius: radii.lg,
        borderWidth: 1,
        flexBasis: 132,
        flexGrow: 1,
        minWidth: 132,
        padding: spacing.md
      }}
    >
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{label}</Text>
      <Text style={{ ...broadcast.rank, color: colors.textPrimary, fontSize: 42 }}>{value}</Text>
      <Text style={{ ...typography.caption, color: colors.neon }}>{detail}</Text>
    </View>
  );
}

function InfoChip({ icon, label, value }: { icon: React.ComponentProps<typeof Icon>["name"]; label: string; value: string }) {
  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: colors.courtLight,
        borderRadius: radii.pill,
        flexDirection: "row",
        gap: spacing.sm,
        paddingHorizontal: spacing.md,
        paddingVertical: spacing.sm
      }}
    >
      <Icon name={icon} size={14} color={colors.neon as string} />
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{label}</Text>
      <Text style={{ ...typography.footnote, color: colors.textPrimary, fontWeight: "800" }}>{value}</Text>
    </View>
  );
}

function LiveMovementStrip({ moves }: { moves: Array<{ entry: RankingEntry; delta: number }> }) {
  const { t } = useI18n();
  return (
    <Card variant="plain" pad="md" style={{ backgroundColor: colors.surfaceCourt }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
        <View
          style={{
            alignItems: "center",
            backgroundColor: colors.courtLight,
            borderRadius: radii.pill,
            height: 34,
            justifyContent: "center",
            width: 34
          }}
        >
          <Icon name="zap" size={16} color={colors.neon as string} />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("ranking.provisional.title")}</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("ranking.provisional.body")}</Text>
        </View>
      </View>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
        {moves.map(({ entry }) => (
          <View
            key={entry.playerId}
            style={{
              backgroundColor: colors.courtLight,
              borderColor: `${colors.neon}24`,
              borderRadius: radii.md,
              borderWidth: 1,
              flexGrow: 1,
              minWidth: 142,
              padding: spacing.sm
            }}
          >
            <Text style={{ ...typography.caption, color: colors.textPrimary }} numberOfLines={1}>
              #{entry.rank} {entry.playerName}
            </Text>
            <Text style={{ ...broadcast.jersey, color: colors.neon, fontSize: 11 }}>
              {t("ranking.pointsBase").replace("{points}", String(entry.points))}
            </Text>
          </View>
        ))}
      </View>
    </Card>
  );
}

function RankingChaseCard({ target, gap, rank, pct }: { target: string; gap: number; rank: number; pct: number }) {
  const { t } = useI18n();
  return (
    <Card variant="premium" style={{ backgroundColor: colors.goldSoft }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
        <View
          style={{
            alignItems: "center",
            backgroundColor: colors.gold,
            borderRadius: radii.lg,
            height: 48,
            justifyContent: "center",
            width: 48
          }}
        >
          <Icon name="trophy" size={22} color={colors.textOnBall as string} />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("ranking.chase.title").replace("{name}", target)}</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary, marginTop: 4 }}>
            {t("ranking.chase.body").replace("{gap}", String(gap)).replace("{rank}", String(rank))}
          </Text>
        </View>
      </View>
      <ProgressBar pct={pct} />
    </Card>
  );
}
