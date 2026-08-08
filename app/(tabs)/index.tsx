import { useEffect, useMemo, useRef, useState } from "react";
import { Alert, Image, Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import Animated, { FadeIn } from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { getHomeData, createProposal, requestMatchJoin } from "@/lib/app-api";
import { compatibilityPct, levelLabel, rankCandidates, rankOpenProposals } from "@/lib/matching";
import { notifyTeamSeeking, sendNotification } from "@/lib/notifications";
import { actionImpact } from "@/lib/feedback";
import { Avatar } from "@/components/avatar";
import { Card } from "@/components/card";
import { Chip } from "@/components/chip";
import { CourtRally } from "@/components/court-rally";
import { DateField } from "@/components/date-field";
import { Icon } from "@/components/icon";
import { bgRivalRadar, bgRivalRadarLight, BroadcastHeader, GlassPanel, LiveBackground } from "@/components/live-visuals";
import { ModalSheet } from "@/components/modal-sheet";
import { PrimaryButton } from "@/components/primary-button";
import { PlayerCard } from "@/components/player-card";
import { ScreenShell } from "@/components/screen-shell";
import { ScreenHero } from "@/components/screen-hero";
import { WebShell } from "@/components/web/web-shell";
import { SearchCandidatesCta } from "@/components/search-candidates-cta";
import { SkeletonCard } from "@/components/skeleton-card";
import { TopPlayersPreview } from "@/components/top-players-preview";
import { buildProvisionalRankings, DIVISION_LABELS } from "@/data/rankings";
import { useI18n } from "@/lib/i18n";
import { PURCHASES_ENABLED } from "@/lib/features";
import { broadcast, colors, spacing, typography, radii, usePlatformLayout, useThemeMode } from "@/theme";
import { Club, MatchCandidate, MatchFormat, MatchJoinRequest, MatchProposal, Player, SearchPreferences, SkillLevel } from "@/types";

const initialPreferences: SearchPreferences = {
  level: "any",
  formats: ["singles", "mixed"],
  ageMin: 18,
  ageMax: 65,
  requireSharedAvailability: true
};

export default function DiscoverScreen() {
  const { isWebDesktop } = usePlatformLayout();
  return isWebDesktop ? <DiscoverWeb /> : <DiscoverNative />;
}

// ---------------------------------------------------------------------------
// WEB — dashboard
// ---------------------------------------------------------------------------

function DiscoverWeb() {
  const state = useDiscoverState();
  const { t } = useI18n();
  const filterGroups = buildFilterGroups(state, t);

  return (
    <LiveBackground source={bgRivalRadar} lightSource={bgRivalRadarLight} overlay={0.48}>
      <WebShell>
        <RivalRadarDashboard state={state} filterGroups={filterGroups} />
      </WebShell>

      <PublishModal state={state} />
    </LiveBackground>
  );
}

// ---------------------------------------------------------------------------
// NATIVO
// ---------------------------------------------------------------------------

function DiscoverNative() {
  const { isWide } = usePlatformLayout();
  const heroBleed = isWide ? spacing.xl : spacing.base;
  const state = useDiscoverState();
  const { t } = useI18n();
  const currentDivision = state.currentPlayer?.level ?? "c";
  const rankingPreview = useMemo(() => {
    // El preview sí puede usar muestras para que el ranking no se vea vacío.
    // La lista de rivales, en cambio, se deriva de rankCandidates y es 100 % real.
    const players = state.allPlayers.length > 0
      ? state.allPlayers
      : state.currentPlayer
        ? [state.currentPlayer]
        : [];
    return buildProvisionalRankings(players, state.clubs)[currentDivision] ?? [];
  }, [currentDivision, state.allPlayers, state.clubs, state.currentPlayer]);

  if (state.currentPlayer?.accountRole === "coach") {
    return (
      <LiveBackground source={bgRivalRadar} lightSource={bgRivalRadarLight} overlay={0.4}>
        <ScreenShell onRefresh={state.refresh}>
          <ScreenHero
            bleed={heroBleed}
            hint={t("coaches.body")}
            stats={[
              { label: t("tabs.ranking"), value: rankingPreview.length },
              { label: t("nav.coaches"), value: 1 }
            ]}
          />
          <TopPlayersPreview entries={rankingPreview} divisionLabel={DIVISION_LABELS[currentDivision]} />
          <Card variant="plain" pad="lg" style={{ borderColor: `${colors.neon}66` }}>
            <View style={{ alignItems: "center", gap: spacing.md }}>
              <View style={{ alignItems: "center", backgroundColor: colors.courtLight, borderRadius: radii.xl, height: 58, justifyContent: "center", width: 58 }}>
                <Icon name="users" size={28} color={colors.neon as string} />
              </View>
              <Text style={{ ...typography.headline, color: colors.textPrimary, textAlign: "center" }}>{t("home.promoteAsCoach")}</Text>
              <Text style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>{t("coaches.body")}</Text>
              <PrimaryButton
                label={PURCHASES_ENABLED ? t("nav.coachAd") : t("ranking.comingSoon")}
                disabled={!PURCHASES_ENABLED}
                onPress={() => router.push("/coach-ad" as never)}
              />
            </View>
          </Card>
        </ScreenShell>
      </LiveBackground>
    );
  }

  return (
    <LiveBackground source={bgRivalRadar} lightSource={bgRivalRadarLight} overlay={0.4}>
      <ScreenShell onRefresh={state.refresh}>
        <Animated.View entering={FadeIn.springify().damping(20)}>
          <ScreenHero
            bleed={heroBleed}
            hint={t("rivals.hero.hint").replace("{count}", String(state.openProposals.length)).replace("{level}", levelLabel(state.currentPlayer?.level ?? "c"))}
            stats={[
              { label: t("tabs.rivals"), value: state.candidates.length },
              { label: t("rivals.hero.open"), value: state.openProposals.length }
            ]}
          />
        </Animated.View>

        <SearchCandidatesCta
          loading={state.searching}
          count={state.visibleCandidates.length}
          onPress={state.searchCandidates}
        />

        <CandidateNameSearch value={state.nameQuery} onChange={state.setNameQuery} />

        {state.loadError ? <DiscoverLoadError message={state.loadError} onRetry={state.searchCandidates} /> : null}

        <TopPlayersPreview
          entries={rankingPreview}
          divisionLabel={DIVISION_LABELS[currentDivision]}
        />

        {/* Publicar partido (propuesta abierta con reserva concreta) */}
        <Card variant="plain" pad="md" style={{ borderColor: colors.borderStrong }}>
          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
            <View style={{ alignItems: "center", backgroundColor: colors.courtLight, borderRadius: radii.lg, height: 46, justifyContent: "center", width: 46 }}>
              <Icon name="calendar-plus" size={22} color={colors.neon as string} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("rivals.publish.title")}</Text>
              <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
                {t("rivals.publish.body")}
              </Text>
            </View>
          </View>
          <PrimaryButton
            label={t("rivals.publish.cta")}
            icon={<Icon name="send" size={16} color={colors.textOnBall as string} />}
            onPress={() => state.setPublishOpen(true)}
          />
        </Card>

        {/* Partidos abiertos de otros jugadores */}
        {state.openProposals.length > 0 ? (
          <View style={{ gap: spacing.sm }}>
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>
              {t("rivals.open.title").replace("{count}", String(state.openProposals.length))}
            </Text>
            {state.openProposals.map(({ proposal, clubName, sharedClub }, index) => (
              <OpenProposalCard
                key={proposal.id}
                proposal={proposal}
                clubName={clubName}
                sharedClub={sharedClub}
                accepting={state.acceptingId === proposal.id}
                requested={state.requestedMatchIds.has(proposal.id)}
                onAccept={() => state.requestProposal(proposal.id)}
                index={index}
              />
            ))}
          </View>
        ) : null}

        <Animated.View entering={FadeIn.delay(80).springify()}>
          <View style={{ gap: spacing.md }}>
            <FilterStrip
              title={t("rivals.filters.level")}
              options={levelOptions.map((level) => ({
                label: optionLabel(t, level),
                active: state.preferences.level === level.value,
                onPress: () => state.setPreferences((v) => ({ ...v, level: level.value }))
              }))}
            />
            <FilterStrip
              title={t("rivals.filters.format")}
              options={formatOptions.map((format) => ({
                label: optionLabel(t, format),
                active: state.preferences.formats.includes(format.value),
                onPress: () => state.toggleFormat(format.value)
              }))}
            />
          </View>
        </Animated.View>

        <CandidateResults state={state} />
      </ScreenShell>

      <PublishModal state={state} />
    </LiveBackground>
  );
}

// ---------------------------------------------------------------------------
// Resultados de búsqueda (nativo): skeletons mientras carga, lista atenuada
// al re-buscar con resultados previos — sin saltos ni flash de estado vacío.
// ---------------------------------------------------------------------------

function CandidateResults({ state }: { state: DiscoverState }) {
  const showSkeletons = state.searching ? state.visibleCandidates.length === 0 : !state.loaded;

  if (showSkeletons) {
    return (
      <Animated.View entering={FadeIn.duration(220)}>
        <SkeletonCard layout="player" count={3} />
      </Animated.View>
    );
  }

  return (
    <View style={{ gap: spacing.sm, opacity: state.searching ? 0.55 : 1 }}>
      <SelfVisibilityCard player={state.currentPlayer} clubs={state.clubs} />
      {state.visibleCandidates.map((candidate, index) => (
        <PlayerCard
          key={candidate.player.id}
          variant="native"
          candidate={candidate}
          clubs={state.clubs}
          index={index}
        />
      ))}
      {state.loaded && state.visibleCandidates.length === 0 ? <EmptyRivals query={state.nameQuery} /> : null}
    </View>
  );
}

/**
 * "Así te ven los demás": tras buscar, el jugador se ve a sí mismo tal y como
 * aparece en la lista de rivales (avatar, nivel, clubes, disponibilidad de
 * búsqueda de equipo). Así queda claro si su perfil está público y cómo lo ve
 * un candidato antes de pedir partido.
 */
function SelfVisibilityCard({ player, clubs }: { player: Player | null; clubs: Club[] }) {
  const { t } = useI18n();
  const { isLight } = useThemeMode();
  if (!player) return null;
  const ownClubs = clubs.filter((club) => player.clubIds.includes(club.id));
  const isPublic = player.profileComplete === true && player.isDemo !== true;
  const seeking = player.seekingTeam === true;
  return (
    <Animated.View entering={FadeIn.springify().damping(18)}>
      <Card
        variant="interactive"
        style={{
          borderColor: `${colors.neon}66`,
          backgroundColor: isLight ? "rgba(82,122,0,0.05)" : "rgba(198,241,53,0.05)"
        }}
      >
        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
          <Avatar name={player.name} photoURL={player.photoURL} size={56} />
          <View style={{ flex: 1, gap: 3 }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary, flex: 1 }} numberOfLines={1}>
                {player.name}
              </Text>
              <View style={{ backgroundColor: colors.courtLight, borderRadius: radii.pill, paddingHorizontal: spacing.sm, paddingVertical: 2 }}>
                <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "800" }}>{t("rivals.self.you")}</Text>
              </View>
            </View>
            <Text style={{ ...typography.caption, color: colors.textSecondary, fontWeight: "500" }}>
              {player.age} {t("rivals.self.years")} · {levelLabel(player.level)} · ★ {player.rating.toFixed(1)}
            </Text>
            {ownClubs.length ? (
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
                <Icon name="map-pin" size={12} color={colors.textTertiary as string} />
                <Text style={{ ...typography.footnote, color: colors.textTertiary, flex: 1 }} numberOfLines={1}>
                  {ownClubs.map((club) => club.name).join(" · ")}
                </Text>
              </View>
            ) : null}
          </View>
        </View>
        <View
          style={{
            alignItems: "center",
            backgroundColor: isPublic ? colors.successBg : colors.warningBg,
            borderColor: isPublic ? `${colors.success}44` : `${colors.warning}44`,
            borderRadius: radii.md,
            borderWidth: 1,
            flexDirection: "row",
            gap: spacing.sm,
            padding: spacing.sm
          }}
        >
          <Icon name={isPublic ? "check-badge" : "clock"} size={16} color={(isPublic ? colors.success : colors.warning) as string} />
          <Text style={{ ...typography.footnote, color: colors.textSecondary, flex: 1 }}>
            {isPublic ? t("rivals.self.public") : t("rivals.self.incomplete")}
          </Text>
          {seeking ? (
            <View style={{ backgroundColor: colors.courtLight, borderRadius: radii.pill, paddingHorizontal: spacing.sm, paddingVertical: 2 }}>
              <Text style={{ ...typography.caption, color: colors.neon, fontWeight: "700" }}>{t("rivals.self.seeking")}</Text>
            </View>
          ) : null}
        </View>
      </Card>
    </Animated.View>
  );
}

// ---------------------------------------------------------------------------
// Filtros horizontales (chips deslizables)
// ---------------------------------------------------------------------------

function FilterStrip({ title, options }: { title: string; options: Array<{ label: string; active: boolean; onPress: () => void }> }) {
  return (
    <View style={{ gap: spacing.xs }}>
      <Text style={{ ...typography.caption, color: colors.textSecondary, fontSize: 12 }}>{title}</Text>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
        {options.map((option) => (
          <Chip key={option.label} label={option.label} active={option.active} onPress={option.onPress} />
        ))}
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Dashboard web
// ---------------------------------------------------------------------------

type DiscoverState = ReturnType<typeof useDiscoverState>;

function RivalRadarDashboard({
  state,
  filterGroups
}: {
  state: DiscoverState;
  filterGroups: ReturnType<typeof buildFilterGroups>;
}) {
  const { t } = useI18n();
  const [showAll, setShowAll] = useState(false);
  const featured = state.visibleCandidates.slice(0, 4);
  const candidates = showAll ? state.visibleCandidates : featured;

  return (
    <View style={{ gap: spacing.lg }}>
      <BroadcastHeader
        kicker="RIVAL RADAR"
        title={t("rivals.dashboard.title")}
        subtitle={t("rivals.dashboard.subtitle")}
        trailing={
          <PrimaryButton
            label={t("rivals.publish.cta")}
            icon={
              <Image
                source={require("@/../assets/generated/home-icons/publish.png")}
                style={{ height: 20, width: 20, borderRadius: 5 }}
              />
            }
            fullWidth={false}
            onPress={() => state.setPublishOpen(true)}
            style={{ minWidth: 190 }}
          />
        }
      />

      {state.openProposals.length > 0 ? (
        <GlassPanel pad="lg">
          <View
            style={{
              alignItems: "center",
              flexDirection: "row",
              justifyContent: "space-between",
              marginBottom: spacing.md
            }}
          >
            <View>
              <Text style={{ ...broadcast.jersey, color: colors.neon, letterSpacing: 1.5, fontSize: 11 }}>
                {t("rivals.live.eyebrow")}
              </Text>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary, fontSize: 18 }}>
                {t("rivals.open.title").replace("{count}", String(state.openProposals.length))}
              </Text>
            </View>
            <PrimaryButton
              label={t("rivals.publish.short")}
              icon={
                <Image
                  source={require("@/../assets/generated/home-icons/publish.png")}
                  style={{ height: 18, width: 18, borderRadius: 4 }}
                />
              }
              fullWidth={false}
              onPress={() => state.setPublishOpen(true)}
              style={{ height: 38, minWidth: 118 }}
            />
          </View>
          <View style={{ gap: spacing.sm }}>
            {state.openProposals.slice(0, 4).map(({ proposal, clubName, sharedClub }) => (
              <OpenProposalRow
                key={proposal.id}
                proposal={proposal}
                clubName={clubName}
                sharedClub={sharedClub}
                accepting={state.acceptingId === proposal.id}
                requested={state.requestedMatchIds.has(proposal.id)}
                onAccept={() => state.requestProposal(proposal.id)}
              />
            ))}
          </View>
        </GlassPanel>
      ) : null}

      <View style={{ alignItems: "stretch", flexDirection: "row", flexWrap: "wrap", gap: spacing.lg }}>
        <View style={{ width: 260, flexShrink: 0, flexGrow: 0 }}>
          <CandidateNameSearch value={state.nameQuery} onChange={state.setNameQuery} compact />
          <WebFilterPanelInline groups={filterGroups} />
        </View>

        <View style={{ flex: 1, gap: spacing.lg, minWidth: 320 }}>
          <RadarLiveBoard state={state} />

          <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
            <View>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("rivals.featured.title")}</Text>
              <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("rivals.featured.subtitle")}</Text>
            </View>
            {state.visibleCandidates.length > 4 ? (
              <PrimaryButton
                label={showAll ? t("rivals.featured.showFeatured") : t("rivals.featured.showAll").replace("{count}", String(state.visibleCandidates.length))}
                variant="outline"
                fullWidth={false}
                onPress={() => setShowAll((value) => !value)}
                style={{ height: 38 }}
              />
            ) : null}
          </View>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
            {candidates.map((candidate, index) => (
              <View key={candidate.player.id} style={{ flexBasis: showAll ? "23%" : 0, flexGrow: 1, minWidth: 160 }}>
                <PlayerCard variant="web" candidate={candidate} clubs={state.clubs} index={index} />
              </View>
            ))}
          </View>
          {state.visibleCandidates.length === 0 ? <EmptyRivals query={state.nameQuery} /> : null}
          {state.loadError ? <DiscoverLoadError message={state.loadError} onRetry={state.searchCandidates} /> : null}
        </View>
      </View>
    </View>
  );
}

/**
 * Radar en vivo (desktop) — la pieza central del Rival Radar: pista con peloteo
 * en el centro, anillos de radar y los mejores rivales orbitando con su
 * compatibilidad, como en el concepto Night Session.
 */
function RadarLiveBoard({ state }: { state: DiscoverState }) {
  const { t } = useI18n();
  const rivals = state.visibleCandidates.slice(0, 4);
  // Posiciones orbitales fijas (4 esquinas suaves) — responsivas por porcentaje.
  const slots: Array<Record<string, string>> = [
    { left: "4%", top: "16%" },
    { right: "4%", top: "22%" },
    { left: "6%", bottom: "12%" },
    { right: "5%", bottom: "18%" }
  ];

  return (
    <GlassPanel style={{ minHeight: 400, overflow: "hidden" }} pad="lg">
      {/* Anillos de radar concéntricos */}
      {[520, 380, 250].map((diameter, index) => (
        <View
          key={diameter}
          pointerEvents="none"
          style={{
            borderColor: `rgba(198,241,53,${0.08 + index * 0.05})`,
            borderRadius: diameter / 2,
            borderWidth: 1,
            height: diameter,
            left: "50%",
            marginLeft: -diameter / 2,
            marginTop: -diameter / 2,
            position: "absolute",
            top: "52%",
            width: diameter
          }}
        />
      ))}

      {/* Cabecera del panel */}
      <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
        <View>
          <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("rivals.radar.title")}</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
            {t("rivals.radar.subtitle")}
          </Text>
        </View>
        <View
          style={{
            alignItems: "center",
            backgroundColor: "rgba(198,241,53,0.12)",
            borderColor: `${colors.neon}44`,
            borderRadius: radii.pill,
            borderWidth: 1,
            flexDirection: "row",
            gap: 6,
            paddingHorizontal: spacing.md,
            paddingVertical: 5
          }}
        >
          <View
            style={{
              backgroundColor: colors.neon,
              borderRadius: 999,
              boxShadow: "0 0 8px #C6F135",
              height: 8,
              width: 8
            }}
          />
          <Text style={{ ...broadcast.jersey, color: colors.neon, fontSize: 11, letterSpacing: 1.4 }}>
            {t("rivals.radar.live")}
          </Text>
        </View>
      </View>

      {/* Pista central con peloteo */}
      <View style={{ alignItems: "center", justifyContent: "center", paddingVertical: spacing.sm }}>
        <View style={{ alignItems: "center", height: 220, justifyContent: "center", width: "100%" }}>
          <CourtRally width={520} height={200} duration={3400} />
        </View>
      </View>

      {/* Rivales orbitando */}
      {rivals.map((candidate, index) => (
        <Animated.View
          key={candidate.player.id}
          entering={FadeIn.delay(250 + index * 120).springify().damping(16)}
          style={[{ position: "absolute" }, slots[index] as object]}
        >
          <RadarRivalChip candidate={candidate} clubs={state.clubs} />
        </Animated.View>
      ))}

      {/* Pie */}
      <Text style={{ ...typography.footnote, color: colors.textSecondary, textAlign: "center" }}>
        {(state.visibleCandidates.length === 1 ? t("rivals.radar.count.one") : t("rivals.radar.count.many")).replace("{count}", String(state.visibleCandidates.length))} ·{" "}
        {t("rivals.radar.level").replace("{level}", levelLabel(state.currentPlayer?.level ?? "c"))}
      </Text>
    </GlassPanel>
  );
}

function RadarRivalChip({ candidate, clubs }: { candidate: MatchCandidate; clubs: Club[] }) {
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  const club = clubs.find((item) => candidate.player.clubIds.includes(item.id));
  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: isLight ? "rgba(255,255,255,0.94)" : "rgba(7,14,10,0.88)",
        borderColor: `${colors.neon}30`,
        borderCurve: "continuous",
        borderRadius: radii.pill,
        borderWidth: 1,
        flexDirection: "row",
        gap: spacing.sm,
        paddingLeft: 5,
        paddingRight: spacing.md,
        paddingVertical: 5
      }}
    >
      <View style={{ borderColor: `${colors.neon}66`, borderRadius: 999, borderWidth: 1.5, padding: 2 }}>
        <Avatar name={candidate.player.name} size={32} />
      </View>
      <View style={{ minWidth: 0 }}>
        <Text style={{ ...typography.caption, color: colors.textPrimary, fontWeight: "700" }} numberOfLines={1}>
          {candidate.player.name.split(" ")[0]}
        </Text>
        <Text style={{ ...typography.footnote, color: colors.textSecondary, fontSize: 11 }} numberOfLines={1}>
          {club ? club.name.replace("Club ", "") : (candidate.sharedSlots[0] ?? t("rivals.radar.flexible"))}
        </Text>
      </View>
      <View
        style={{
          backgroundColor: colors.accentFill,
          borderRadius: radii.pill,
          paddingHorizontal: spacing.sm,
          paddingVertical: 2
        }}
      >
        <Text style={{ ...broadcast.stat, color: colors.onAccentFill, fontSize: 12 }}>
          {compatibilityPct(candidate.score)}%
        </Text>
      </View>
    </View>
  );
}

function WebFilterPanelInline({ groups }: { groups: ReturnType<typeof buildFilterGroups> }) {
  return (
    <View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.lg, borderWidth: 1, gap: spacing.md, padding: spacing.base }}>
      {groups.map((group) => (
        <View key={group.label} style={{ gap: spacing.xs }}>
          <Text style={{ ...typography.caption, color: colors.textSecondary, fontSize: 12 }}>{group.label}</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
            {group.options.map((option) => (
              <Chip key={option.label} label={option.label} active={option.active} onPress={option.onPress} />
            ))}
          </View>
        </View>
      ))}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Tarjetas de propuestas abiertas
// ---------------------------------------------------------------------------

function OpenProposalCard({
  proposal,
  clubName,
  sharedClub,
  accepting,
  requested,
  onAccept,
  index
}: {
  proposal: MatchProposal;
  clubName: string;
  sharedClub: boolean;
  accepting: boolean;
  requested: boolean;
  onAccept: () => void;
  index: number;
}) {
  const { t, lang } = useI18n();
  return (
    <Animated.View entering={FadeIn.delay(index * 50).springify().damping(18)}>
      <Card variant="elevated" style={{ borderColor: sharedClub ? `${colors.court}33` : colors.border }}>
        <View style={{ alignItems: "flex-start", flexDirection: "row", gap: spacing.md }}>
          <View style={{ alignItems: "center", backgroundColor: colors.courtLight, borderRadius: radii.pill, height: 44, justifyContent: "center", width: 44 }}>
            <Icon name="calendar-plus" size={20} color={colors.neon as string} />
          </View>
          <View style={{ flex: 1, gap: 4 }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary, flex: 1 }} numberOfLines={1}>
                {clubName}
              </Text>
              {sharedClub ? (
                <View style={{ backgroundColor: colors.courtLight, borderRadius: radii.pill, paddingHorizontal: spacing.sm, paddingVertical: 2 }}>
                  <Text style={{ ...typography.footnote, color: colors.neon, fontWeight: "800" }}>{t("rivals.open.yourClub")}</Text>
                </View>
              ) : null}
            </View>
            <Text style={{ ...typography.caption, color: colors.textSecondary }}>
              {formatReservation(proposal)} · {t("common.court").replace("{court}", String(proposal.court))} · {formatAcceptedLevels(proposal)} · {formatLabel(proposal.format)}
            </Text>
            {proposal.message ? (
              <Text style={{ ...typography.footnote, color: colors.textTertiary }} numberOfLines={2}>
                {proposal.message}
              </Text>
            ) : null}
          </View>
        </View>
        <PrimaryButton
          label={requested ? t("matches.join.sent") : accepting ? t("matches.join.sending") : t("matches.join.request")}
          icon={<Icon name="check" size={16} color={colors.textOnBrand as string} />}
          disabled={accepting || requested}
          onPress={onAccept}
        />
      </Card>
    </Animated.View>
  );
}

function OpenProposalRow({
  proposal,
  clubName,
  sharedClub,
  accepting,
  requested,
  onAccept
}: {
  proposal: MatchProposal;
  clubName: string;
  sharedClub: boolean;
  accepting: boolean;
  requested: boolean;
  onAccept: () => void;
}) {
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: sharedClub
          ? (isLight ? "rgba(82,122,0,0.07)" : "rgba(198,241,53,0.06)")
          : (isLight ? "rgba(27,55,36,0.03)" : "rgba(255,255,255,0.02)"),
        borderColor: sharedClub ? `${colors.neon}33` : colors.border,
        borderRadius: radii.lg,
        borderWidth: 1,
        flexDirection: "row",
        gap: spacing.md,
        paddingHorizontal: spacing.md,
        paddingVertical: spacing.md
      }}
    >
      <View
        style={{
          alignItems: "center",
          backgroundColor: colors.courtLight,
          borderRadius: radii.md,
          height: 46,
          justifyContent: "center",
          width: 46
        }}
      >
        <Icon name="calendar-plus" size={20} color={colors.neon as string} />
      </View>
      <View style={{ flex: 1, gap: 3, minWidth: 0 }}>
        <View style={{ alignItems: "center", flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
          <Text style={{ ...typography.subheadline, color: colors.textPrimary, flexShrink: 1 }} numberOfLines={1}>
            {clubName}
          </Text>
          {sharedClub ? (
            <View
              style={{
                backgroundColor: colors.courtLight,
                borderRadius: radii.pill,
                paddingHorizontal: spacing.sm,
                paddingVertical: 2
              }}
            >
              <Text style={{ ...typography.footnote, color: colors.neon, fontWeight: "800" }}>{t("rivals.open.yourClub")}</Text>
            </View>
          ) : null}
        </View>
        <Text style={{ ...typography.footnote, color: colors.textSecondary }} numberOfLines={1}>
          {formatReservation(proposal)} · {t("common.court").replace("{court}", String(proposal.court))} · {formatAcceptedLevels(proposal)}
        </Text>
      </View>
      <PrimaryButton
        label={requested ? t("rivals.open.sentShort") : accepting ? "…" : t("rivals.open.requestShort")}
        fullWidth={false}
        disabled={accepting || requested}
        onPress={onAccept}
        style={{ minWidth: 112, height: 42 }}
      />
    </View>
  );
}

// ---------------------------------------------------------------------------
// Estado compartido
// ---------------------------------------------------------------------------

function useDiscoverState() {
  const { isWide } = usePlatformLayout();
  const { t } = useI18n();
  const params = useLocalSearchParams<{ publish?: string }>();
  const latestRequest = useRef(0);
  const handledPublishParam = useRef(false);
  const [candidates, setCandidates] = useState<MatchCandidate[]>([]);
  const [allPlayers, setAllPlayers] = useState<Player[]>([]);
  const [clubs, setClubs] = useState<Club[]>([]);
  const [currentPlayer, setCurrentPlayer] = useState<Player | null>(null);
  const [allProposals, setAllProposals] = useState<MatchProposal[]>([]);
  const [joinRequests, setJoinRequests] = useState<MatchJoinRequest[]>([]);
  const [searching, setSearching] = useState(false);
  /** true tras el primer intento de carga — evita el flash de "Sin rivales". */
  const [loaded, setLoaded] = useState(false);
  const [publishOpen, setPublishOpen] = useState(false);
  const [acceptingId, setAcceptingId] = useState<string | null>(null);
  const [preferences, setPreferences] = useState(initialPreferences);
  const [nameQuery, setNameQuery] = useState("");
  const [loadError, setLoadError] = useState<string | null>(null);

  useEffect(() => {
    if (params.publish === "1" && currentPlayer && !handledPublishParam.current) {
      handledPublishParam.current = true;
      setPublishOpen(true);
    }
  }, [currentPlayer, params.publish]);

  const loadCandidates = async (prefs = preferences) => {
    const requestId = ++latestRequest.current;
    const value = await getHomeData(prefs);
    if (requestId !== latestRequest.current) return value;
    setCandidates(value.candidates);
    setAllPlayers(value.players);
    setClubs(value.clubs);
    setCurrentPlayer(value.currentPlayer);
    setAllProposals(value.proposals);
    setJoinRequests(value.joinRequests);
    setLoadError(null);
    return value;
  };

  useEffect(() => {
    loadCandidates()
      .catch((error: unknown) => setLoadError(describeError(error)))
      .finally(() => setLoaded(true));
  }, [preferences]);

  const searchCandidates = async () => {
    setSearching(true);
    try {
      await loadCandidates();
      if (process.env.EXPO_OS === "ios") {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }
    } catch (error: unknown) {
      setLoadError(describeError(error));
    } finally {
      setSearching(false);
    }
  };

  const publishMatch = async (input: PublishInput) => {
    if (!currentPlayer) return;
    try {
      validatePublishInput(input, clubs, t);
      await createProposal({
        clubId: input.clubId,
        startsAt: buildStartsAt(input.reservationDate, input.startTime).toISOString(),
        reservationTime: `${input.startTime}-${input.endTime}`,
        court: input.court,
        format: "singles",
        division: currentPlayer.level,
        acceptedLevels: input.acceptedLevels,
        message: (input.message.trim() || defaultPublishMessage(input, clubs)).slice(0, 280)
      });
      setPublishOpen(false);
      if (process.env.EXPO_OS === "ios") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert(t("rivals.alert.published"), t("rivals.alert.publishedBody"));
      // Avisos al publicar partido casual: fan-out a todos los compatibles de
      // la misma ciudad (preferencia teamSeeking la filtra el receptor) y
      // aviso directo de interés si ya había solicitudes pendientes. Nunca
      // bloquea el flujo principal.
      if (currentPlayer) {
        void notifyTeamSeeking(
          currentPlayer,
          input.acceptedLevels,
          t("notifications.toast.team_seeking").replace("{name}", currentPlayer.name)
        );
      }
      await loadCandidates();
    } catch (error) {
      Alert.alert(t("rivals.alert.publishFailed"), describeError(error));
    }
  };

  const requestProposal = async (id: string) => {
    setAcceptingId(id);
    try {
      const request = await requestMatchJoin(id);
      setJoinRequests((current) => [...current.filter((item) => item.id !== request.id), request]);
      if (process.env.EXPO_OS === "ios") Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert(t("matches.join.sent"), t("rivals.alert.sentBody"));
      // El organizador recibe el aviso de interés (preferencia matchInterest).
      if (currentPlayer) {
        void sendNotification({
          recipientId: request.ownerId,
          type: "match_interest",
          actorId: currentPlayer.id,
          actorName: currentPlayer.name,
          message: t("notifications.toast.match_interest").replace("{name}", currentPlayer.name),
          route: "/matches"
        });
      }
    } catch (error) {
      Alert.alert(t("matches.alert.requestFailed"), describeError(error));
    } finally {
      setAcceptingId(null);
    }
  };

  const toggleFormat = (format: SearchPreferences["formats"][number]) => {
    setPreferences((value) => {
      const formats = value.formats.includes(format)
        ? value.formats.filter((item) => item !== format)
        : [...value.formats, format];
      return { ...value, formats: formats.length > 0 ? formats : [format] };
    });
  };

  // Propuestas abiertas relevantes: nivel compatible, clubes del jugador primero.
  const openProposals = useMemo(
    () => (currentPlayer ? rankOpenProposals(currentPlayer, allProposals, clubs) : []),
    [currentPlayer, allProposals, clubs]
  );

  const visibleCandidates = useMemo(() => {
    const query = normalizeSearchText(nameQuery.trim());
    if (!query) return candidates;
    if (!currentPlayer) return [];
    return rankCandidates(currentPlayer, allPlayers, {
      level: "any",
      formats: ["singles", "doubles", "mixed"],
      ageMin: 16,
      ageMax: 100,
      requireSharedAvailability: false
    }).filter((candidate) => normalizeSearchText(candidate.player.name).includes(query));
  }, [allPlayers, candidates, currentPlayer, nameQuery]);
  const requestedMatchIds = useMemo(() => new Set(joinRequests.filter((item) => item.status === "pending" || item.status === "accepted").map((item) => item.matchId)), [joinRequests]);

  return {
    isWide,
    candidates,
    visibleCandidates,
    allPlayers,
    clubs,
    currentPlayer,
    allProposals,
    joinRequests,
    requestedMatchIds,
    openProposals,
    nameQuery,
    setNameQuery,
    loadError,
    loaded,
    searching,
    searchCandidates,
    /** Recarga para pull-to-refresh (sin el delay teatral de searchCandidates). */
    refresh: () => loadCandidates(),
    preferences,
    setPreferences,
    toggleFormat,
    publishOpen,
    setPublishOpen,
    publishMatch,
    acceptingId,
    requestProposal
  };
}

function PublishModal({ state }: { state: ReturnType<typeof useDiscoverState> }) {
  const { currentPlayer, clubs, publishOpen, setPublishOpen, publishMatch } = state;

  return (
    <ModalSheet visible={publishOpen} onClose={() => setPublishOpen(false)} maxWidth={520}>
      <PublishForm
        clubs={clubs}
        defaultClubId={currentPlayer?.clubIds[0]}
        defaultLevel={currentPlayer?.level}
        onCancel={() => setPublishOpen(false)}
        onSubmit={publishMatch}
      />
    </ModalSheet>
  );
}

type PublishInput = {
  clubId: string;
  reservationDate: string;
  startTime: string;
  endTime: string;
  court: number;
  format: MatchFormat;
  acceptedLevels: SkillLevel[];
  message: string;
};

function PublishForm({
  clubs,
  defaultClubId,
  defaultLevel,
  onCancel,
  onSubmit
}: {
  clubs: Club[];
  defaultClubId?: string;
  defaultLevel?: MatchProposal["division"];
  onCancel: () => void;
  onSubmit: (input: PublishInput) => void;
}) {
  const { t } = useI18n();
  const [clubId, setClubId] = useState(defaultClubId ?? clubs[0]?.id ?? "");
  const [reservationDate, setReservationDate] = useState(() => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    return toLocalDateInput(tomorrow);
  });
  const [startTime, setStartTime] = useState("10:00");
  const [endTime, setEndTime] = useState("12:00");
  const [court, setCourt] = useState(1);
  const [message, setMessage] = useState("");
  const [acceptedLevels, setAcceptedLevels] = useState<SkillLevel[]>(defaultLevel ? [defaultLevel] : ["c"]);

  const selectedClub = clubs.find((club) => club.id === clubId);
  const courtOptions = Array.from({ length: Math.max(1, selectedClub?.courts ?? 1) }, (_, index) => index + 1);
  const validationMessage = getPublishValidationMessage({
    clubId,
    reservationDate,
    startTime,
    endTime,
    court,
    format: "singles",
    acceptedLevels,
    message
  }, clubs, t);
  const canSubmit = validationMessage === null && acceptedLevels.length > 0;

  useEffect(() => {
    if (selectedClub && court > selectedClub.courts) setCourt(1);
  }, [court, selectedClub]);

  return (
    <View style={{ gap: spacing.md }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm, marginBottom: spacing.xs }}>
        <View style={{ alignItems: "center", backgroundColor: colors.goldSoft, borderRadius: radii.xl, height: 40, justifyContent: "center", width: 40 }}>
          <Icon name="tennis" size={20} color={colors.gold} />
        </View>
        <View>
          <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("rivals.publish.title")}</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("rivals.form.subtitle")}</Text>
        </View>
      </View>

      <FormRow label={t("rivals.form.club")}>
        <ScrollView
          horizontal
          contentContainerStyle={{ gap: spacing.xs, paddingRight: spacing.md }}
          showsHorizontalScrollIndicator={false}
        >
          {clubs.map((club) => (
            <Chip key={club.id} label={club.name} active={clubId === club.id} onPress={() => setClubId(club.id)} />
          ))}
        </ScrollView>
      </FormRow>

      <FormRow label={t("rivals.form.date")}>
        <DateField value={reservationDate} onChange={setReservationDate} minimumDate={new Date()} />
      </FormRow>

      <View style={{ flexDirection: "row", gap: spacing.sm }}>
        <FormRow label={t("rivals.form.start")} style={{ flex: 1 }}>
          <FormInput value={startTime} onChange={setStartTime} placeholder="10:00" maxLength={5} keyboardType="numbers-and-punctuation" />
        </FormRow>
        <FormRow label={t("rivals.form.end")} style={{ flex: 1 }}>
          <FormInput value={endTime} onChange={setEndTime} placeholder="12:00" maxLength={5} keyboardType="numbers-and-punctuation" />
        </FormRow>
      </View>

      <FormRow label={t("rivals.form.court")}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {courtOptions.map((courtNumber) => (
            <Chip
              key={courtNumber}
              label={String(courtNumber)}
              active={court === courtNumber}
              onPress={() => setCourt(courtNumber)}
            />
          ))}
        </View>
      </FormRow>

      <FormRow label={t("rivals.filters.format")}>
        <Chip label={t("onboarding.format.singles")} active />
        <Text style={{ ...typography.footnote, color: colors.textTertiary }}>
          {t("rivals.form.formatNote")}
        </Text>
      </FormRow>

      <FormRow label={t("rivals.form.levels")}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {levelOptions.filter((item) => item.value !== "any").map((item) => {
            const level = item.value as SkillLevel;
            return <Chip key={level} label={optionLabel(t, item)} active={acceptedLevels.includes(level)} onPress={() => setAcceptedLevels((current) => current.includes(level) ? current.filter((value) => value !== level) : [...current, level])} />;
          })}
        </View>
        <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
          {t("rivals.form.levelsNote")}
        </Text>
      </FormRow>

      <FormRow label={t("rivals.form.message")}>
        <FormInput value={message} onChange={setMessage} placeholder={t("rivals.form.messagePlaceholder")} multiline maxLength={280} />
        <Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "right", fontVariant: ["tabular-nums"] }}>
          {message.length}/280
        </Text>
      </FormRow>

      {validationMessage ? (
        <Text accessibilityLiveRegion="polite" style={{ ...typography.footnote, color: colors.warning }}>
          {validationMessage}
        </Text>
      ) : null}

      <View style={{ gap: spacing.sm, marginTop: spacing.sm }}>
        <PrimaryButton
          label={t("rivals.publish.cta")}
          size="lg"
          icon={<Icon name="send" size={16} color={colors.textOnBrand as string} />}
          disabled={!canSubmit}
          onPress={() => onSubmit({ clubId, reservationDate, startTime, endTime, court, format: "singles", acceptedLevels, message })}
        />
        <PrimaryButton label={t("common.cancel")} variant="ghost" onPress={onCancel} />
      </View>
    </View>
  );
}

function FormRow({
  label,
  children,
  style
}: {
  label: string;
  children: React.ReactNode;
  style?: import("react-native").ViewStyle;
}) {
  return (
    <View style={[{ gap: spacing.xs }, style]}>
      <Text style={{ ...typography.caption, color: colors.textSecondary, textTransform: "uppercase", letterSpacing: 0.8 }}>
        {label}
      </Text>
      {children}
    </View>
  );
}

/** Input React Native compartido por Android, iOS y web. */
function FormInput({
  value,
  onChange,
  placeholder,
  multiline = false,
  maxLength,
  keyboardType = "default"
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  multiline?: boolean;
  maxLength?: number;
  keyboardType?: "default" | "numbers-and-punctuation";
}) {
  return (
    <TextInput
      value={value}
      onChangeText={onChange}
      placeholder={placeholder}
      placeholderTextColor={colors.textTertiary as string}
      multiline={multiline}
      maxLength={maxLength}
      keyboardType={keyboardType}
      autoCapitalize={multiline ? "sentences" : "none"}
      autoCorrect={multiline}
      textAlignVertical={multiline ? "top" : "center"}
      style={{
        ...typography.body,
        backgroundColor: colors.surface,
        borderColor: colors.borderStrong as string,
        borderRadius: radii.md,
        borderWidth: 1,
        color: colors.textPrimary as string,
        minHeight: multiline ? 88 : 46,
        paddingHorizontal: spacing.md,
        paddingVertical: multiline ? spacing.md : spacing.sm
      }}
    />
  );
}

function EmptyRivals({ query = "" }: { query?: string }) {
  return (
    <Card variant="glass">
      <View style={{ alignItems: "center", gap: spacing.sm, paddingVertical: spacing.lg }}>
        <Icon name="search" size={32} color={colors.textTertiary as string} />
        <Text style={{ ...typography.subheadline, color: colors.textPrimary, textAlign: "center" }}>
          Sin rivales con estos filtros
        </Text>
        <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14, textAlign: "center" }}>
          {query.trim() ? `No encontramos a “${query.trim()}”. Prueba con nombre o apellido.` : "Prueba con otro nivel o formato."}
        </Text>
      </View>
    </Card>
  );
}

function CandidateNameSearch({ value, onChange, compact = false }: { value: string; onChange: (value: string) => void; compact?: boolean }) {
  return (
    <View style={{ marginBottom: compact ? spacing.md : 0, gap: spacing.xs }}>
      {!compact ? <Text style={{ ...typography.caption, color: colors.textSecondary }}>Buscar jugador por nombre</Text> : null}
      <View style={{ alignItems: "center", backgroundColor: colors.surface, borderColor: value ? `${colors.neon}66` : colors.borderStrong, borderRadius: radii.pill, borderWidth: 1, flexDirection: "row", gap: spacing.sm, minHeight: 48, paddingHorizontal: spacing.md }}>
        <Icon name="search" size={18} color={(value ? colors.neon : colors.textTertiary) as string} />
        <TextInput
          accessibilityLabel="Buscar jugador por nombre"
          autoCapitalize="words"
          autoCorrect={false}
          onChangeText={onChange}
          placeholder="Nombre o apellido"
          placeholderTextColor={colors.textTertiary as string}
          returnKeyType="search"
          style={{ ...typography.body, color: colors.textPrimary, flex: 1, minWidth: 0, paddingVertical: 10 }}
          value={value}
        />
        {value ? (
          <Pressable accessibilityLabel="Limpiar búsqueda" hitSlop={8} onPress={() => onChange("")}>
            <Icon name="close" size={17} color={colors.textSecondary as string} />
          </Pressable>
        ) : null}
      </View>
    </View>
  );
}

function DiscoverLoadError({ message, onRetry }: { message: string; onRetry: () => Promise<void> }) {
  return (
    <Card style={{ backgroundColor: colors.warningBg, borderColor: `${colors.warning}55` }}>
      <View style={{ alignItems: "center", flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
        <Icon name="clock" size={20} color={colors.warning as string} />
        <Text selectable style={{ ...typography.body, color: colors.textPrimary, flex: 1, minWidth: 180 }}>{message}</Text>
        <PrimaryButton label="Reintentar" variant="outline" fullWidth={false} onPress={() => void onRetry()} />
      </View>
    </Card>
  );
}

function normalizeSearchText(value: string) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase("es");
}

const levelOptions: Array<{ label?: string; labelKey?: string; value: "any" | SkillLevel }> = [
  { labelKey: "levels.all", value: "any" as const },
  { labelKey: "onboarding.level.novato", value: "novato" as const },
  { label: "D", value: "d" as const },
  { label: "C", value: "c" as const },
  { label: "B", value: "b" as const },
  { label: "A", value: "a" as const }
];

const formatOptions = [
  { labelKey: "onboarding.format.singles", value: "singles" as const },
  { labelKey: "onboarding.format.doubles", value: "doubles" as const },
  { labelKey: "onboarding.format.mixed", value: "mixed" as const }
];

/** Resuelve la etiqueta visible de una opción con `labelKey` opcional. */
function optionLabel(t: (key: string) => string, option: { label?: string; labelKey?: string }) {
  return option.labelKey ? t(option.labelKey) : option.label ?? "";
}

function buildFilterGroups(state: ReturnType<typeof useDiscoverState>, t: (key: string) => string) {
  return [
    {
      label: t("rivals.filters.level"),
      options: levelOptions.map((level) => ({
        label: optionLabel(t, level),
        active: state.preferences.level === level.value,
        onPress: () => state.setPreferences((v) => ({ ...v, level: level.value }))
      }))
    },
    {
      label: t("rivals.filters.format"),
      options: formatOptions.map((format) => ({
        label: optionLabel(t, format),
        active: state.preferences.formats.includes(format.value),
        onPress: () => state.toggleFormat(format.value)
      }))
    }
  ];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatLabel(format: MatchFormat) {
  return format === "singles" ? "Singles" : format === "doubles" ? "Dobles" : "Mixto";
}

function formatReservation(proposal: MatchProposal) {
  const date = new Date(proposal.startsAt);
  const day = date.toLocaleDateString("es-GT", { weekday: "long", day: "numeric", month: "short" });
  return `${day} · ${proposal.reservationTime.replace("-", "–")}`;
}

function formatAcceptedLevels(proposal: MatchProposal) {
  const levels = proposal.acceptedLevels?.length ? proposal.acceptedLevels : [proposal.division];
  return `Niveles ${levels.map(levelLabel).join(", ")}`;
}

function toLocalDateInput(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function buildStartsAt(dateInput: string, time: string) {
  const dateMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateInput);
  const timeMatch = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(time);
  if (!dateMatch || !timeMatch) throw new Error("Revisa la fecha y usa horas en formato HH:MM.");
  const [, yearText, monthText, dayText] = dateMatch;
  const [, hourText, minuteText] = timeMatch;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const hours = Number(hourText);
  const minutes = Number(minuteText);
  const result = new Date(year, month - 1, day, hours, minutes, 0, 0);
  if (
    result.getFullYear() !== year
    || result.getMonth() !== month - 1
    || result.getDate() !== day
    || result.getHours() !== hours
    || result.getMinutes() !== minutes
  ) {
    throw new Error("La fecha de la reserva no es válida.");
  }
  return result;
}

function getPublishValidationMessage(input: PublishInput, clubs: Club[], t: (key: string) => string): string | null {
  const club = clubs.find((item) => item.id === input.clubId);
  if (!club) return t("rivals.validation.club");
  if (!Number.isInteger(input.court) || input.court < 1 || input.court > club.courts) {
    return t("rivals.validation.court").replace("{courts}", String(club.courts));
  }
  let startsAt: Date;
  let endsAt: Date;
  try {
    startsAt = buildStartsAt(input.reservationDate, input.startTime);
    endsAt = buildStartsAt(input.reservationDate, input.endTime);
  } catch {
    return t("rivals.validation.dateTime");
  }
  if (endsAt <= startsAt) return t("rivals.validation.endAfterStart");
  if (startsAt.getTime() < Date.now() + 5 * 60 * 1000) {
    return t("rivals.validation.future");
  }
  if (input.message.length > 280) return t("rivals.validation.messageTooLong");
  return null;
}

function validatePublishInput(input: PublishInput, clubs: Club[], t: (key: string) => string) {
  const message = getPublishValidationMessage(input, clubs, t);
  if (message) throw new Error(message);
}

function defaultPublishMessage(input: PublishInput, clubs: Club[]) {
  const club = clubs.find((c) => c.id === input.clubId)?.name ?? "mi club";
  return `Reservé la cancha ${input.court} de ${input.startTime} a ${input.endTime} en ${club}. ¿Alguien se anima?`;
}

function describeError(error: unknown) {
  if (error instanceof Error) return error.message;
  return "Intenta de nuevo en unos momentos.";
}
