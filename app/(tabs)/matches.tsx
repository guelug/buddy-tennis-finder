import { useEffect, useMemo, useState } from "react";
import { Alert, Text, View } from "react-native";
import Animated, { FadeIn, SlideInRight } from "react-native-reanimated";
import { router } from "expo-router";
import * as Haptics from "expo-haptics";
import { Card } from "@/components/card";
import { Chip } from "@/components/chip";
import { ConceptHero } from "@/components/concept-hero";
import { Icon, type IconName } from "@/components/icon";
import { bgMatchControl, bgMatchControlLight, BroadcastHeader, GlassPanel, LiveBackground, LiveBallStage } from "@/components/live-visuals";
import { ScreenShell } from "@/components/screen-shell";
import { ScreenHero } from "@/components/screen-hero";
import { PrimaryButton } from "@/components/primary-button";
import { StatusBadge } from "@/components/status-badge";
import { LoadingView } from "@/components/loading-view";
import { Avatar } from "@/components/avatar";
import { SegmentedTabs } from "@/components/segmented-tabs";
import { ModalSheet } from "@/components/modal-sheet";
import { MatchRoomCard, MatchRoomSheet } from "@/components/match-room";
import { WazeLogo } from "@/components/icons/waze-logo";
import { WebShell } from "@/components/web/web-shell";
import { getMatchRooms, roomAffordances } from "@/lib/match-room";
import { getHomeData, requestMatchJoin, respondToMatchJoinRequest, updateProposalStatus } from "@/lib/app-api";
import { isLevelCompatible, levelLabel } from "@/lib/matching";
import { openInWaze } from "@/lib/waze";
import { useAuth } from "@/lib/firebase-auth";
import { useI18n } from "@/lib/i18n";
import { broadcast, colors, radii, shadows, spacing, typography, usePlatformLayout } from "@/theme";
import { Club, MatchJoinRequest, MatchProposal, MatchRoom, Player } from "@/types";

type MatchFilter = "all" | "proposed" | "accepted" | "results";

export default function MatchesScreen() {
  const { isWebDesktop } = usePlatformLayout();
  return isWebDesktop ? <MatchesWeb /> : <MatchesNative />;
}

function MatchesWeb() {
  const state = useMatchesState();
  const { t } = useI18n();

  if (state.loading) return <LoadingView />;
  if (state.error) return <MatchesLoadError message={state.error} onRetry={state.refresh} />;

  const filterChips: Array<{ id: MatchFilter; label: string }> = [
    { id: "all", label: `${t("matches.filters.all")} (${state.counts.all})` },
    { id: "proposed", label: `${t("matches.filters.proposed")} (${state.counts.proposed})` },
    { id: "accepted", label: `${t("matches.filters.accepted")} (${state.counts.accepted})` },
    { id: "results", label: `${t("matches.filters.results")} (${state.rooms.length})` }
  ];

  return (
    <LiveBackground source={bgMatchControl} lightSource={bgMatchControlLight} overlay={0.36}>
      <WebShell width="wide">
        <MatchControlDashboard state={state} />

        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {filterChips.map((chip) => (
            <Chip
              key={chip.id}
              label={chip.label}
              active={state.filter === chip.id}
              onPress={() => state.setFilter(chip.id)}
            />
          ))}
        </View>

        {state.filter === "results" ? (
          <RoomsList state={state} columns={2} />
        ) : state.filtered.length === 0 ? (
          <EmptyState filter={state.filter} />
        ) : (
          <View style={{ gap: spacing.md }}>
            {state.filtered.map((proposal, index) => (
              <MatchRowWeb key={proposal.id} proposal={proposal} index={index} state={state} />
            ))}
          </View>
        )}
      </WebShell>

      <RoomModal state={state} />
    </LiveBackground>
  );
}

function MatchesNative() {
  const { isWide } = usePlatformLayout();
  const heroBleed = isWide ? spacing.xl : spacing.base;
  const state = useMatchesState();
  const { t } = useI18n();

  if (state.loading) return <LoadingView />;
  if (state.error) return <MatchesLoadError message={state.error} onRetry={state.refresh} />;

  return (
    <LiveBackground source={bgMatchControl} lightSource={bgMatchControlLight} overlay={0.4}>
      <ScreenShell onRefresh={state.refresh}>
        <Animated.View entering={FadeIn.springify().damping(20)}>
          <ScreenHero
            bleed={heroBleed}
            hint={t("matches.hero.hint")}
            stats={[
              { label: t("matches.hero.todo"), value: state.actionCount },
              { label: t("matches.filters.accepted"), value: state.counts.accepted }
            ]}
          />
        </Animated.View>

        <MatchOpsHero state={state} />

        {state.actionCount > 0 ? (
          <ActionBanner count={state.actionCount} onPress={() => state.setFilter("results")} />
        ) : null}

        <Animated.View entering={FadeIn.delay(60).springify()}>
          <SegmentedTabs<MatchFilter>
            value={state.filter}
            onChange={state.setFilter}
            tabs={[
              { id: "all", label: t("matches.tabs.all"), count: state.counts.all },
              { id: "proposed", label: t("matches.tabs.proposed"), count: state.counts.proposed },
              { id: "accepted", label: t("matches.tabs.accepted"), count: state.counts.accepted },
              { id: "results", label: t("matches.tabs.results"), count: state.rooms.length }
            ]}
          />
        </Animated.View>

        {state.filter === "results" ? (
          <>
            <PrimaryButton
              label={t("doubles.title")}
              variant="outline"
              icon={<Icon name="users" size={17} color={colors.neon as string} />}
              onPress={() => router.push("/record-doubles" as never)}
            />
            <RoomsList state={state} columns={1} />
          </>
        ) : state.filtered.length === 0 ? (
          <EmptyState filter={state.filter} />
        ) : (
          <View style={{ gap: spacing.sm }}>
            {state.filtered.map((proposal, index) => (
              <MatchRowNative key={proposal.id} proposal={proposal} index={index} state={state} />
            ))}
          </View>
        )}
      </ScreenShell>

      <RoomModal state={state} />
    </LiveBackground>
  );
}

function MatchesLoadError({ message, onRetry }: { message: string; onRetry: () => Promise<void> }) {
  const { t } = useI18n();
  return (
    <LiveBackground source={bgMatchControl} lightSource={bgMatchControlLight} overlay={0.4}>
      <ScreenShell>
        <Card variant="elevated">
          <View style={{ alignItems: "center", gap: spacing.md, paddingVertical: spacing.xl }}>
            <View style={{ alignItems: "center", backgroundColor: colors.warningBg, borderRadius: radii.xl, height: 64, justifyContent: "center", width: 64 }}>
              <Icon name="clock" size={28} color={colors.warning as string} />
            </View>
            <Text selectable style={{ ...typography.subheadline, color: colors.textPrimary, textAlign: "center" }}>
              {t("matches.error.title")}
            </Text>
            <Text selectable style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>
              {message}
            </Text>
            <PrimaryButton label={t("common.retry")} onPress={() => void onRetry().catch(() => {})} />
          </View>
        </Card>
      </ScreenShell>
    </LiveBackground>
  );
}

function MatchControlDashboard({ state }: { state: MatchesState }) {
  const { t } = useI18n();
  const primaryRoom = state.rooms[0];
  const header = (
    <BroadcastHeader
      kicker="MATCH CONTROL"
      title={t("tabs.matches")}
      subtitle={t("matches.dashboard.subtitle")}
      trailing={
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
          <MatchStat icon="users" value={state.counts.accepted} label={t("matches.filters.accepted")} />
          <MatchStat icon="clock" value={state.counts.proposed} label={t("matches.filters.proposed")} />
          <MatchStat icon="trophy" value={state.rooms.length} label={t("matches.stats.played")} />
        </View>
      }
    />
  );

  if (!primaryRoom) {
    return (
      <View style={{ gap: spacing.lg }}>
        {header}
        <GlassPanel style={{ minHeight: 280 }}>
          <View style={{ alignItems: "center", flex: 1, gap: spacing.md, justifyContent: "center", padding: spacing.xl }}>
            <View style={{ alignItems: "center", backgroundColor: colors.courtLight, borderRadius: radii.xl, height: 72, justifyContent: "center", width: 72 }}>
              <Icon name="calendar-plus" size={32} color={colors.neon as string} />
            </View>
            <Text style={{ ...broadcast.hero, color: colors.textPrimary, fontSize: 30, lineHeight: 34, textAlign: "center" }}>
              {t("matches.dashboard.emptyTitle")}
            </Text>
            <Text style={{ ...typography.body, color: colors.textSecondary, maxWidth: 560, textAlign: "center" }}>
              {t("matches.dashboard.emptyBody")}
            </Text>
            <PrimaryButton label={t("matches.dashboard.viewBookings")} fullWidth={false} onPress={() => state.setFilter("accepted")} />
          </View>
        </GlassPanel>
      </View>
    );
  }

  const score = primaryRoom.result?.sets?.map((set) => `${set.a}-${set.b}`).join("  ") ?? t("matches.score.pending");
  const leftName = primaryRoom.teamA.playerNames.join(", ");
  const rightName = primaryRoom.teamB.playerNames.join(", ");

  return (
    <View style={{ gap: spacing.lg }}>
      {header}

      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.lg, alignItems: "stretch" }}>
        <View style={{ width: 280, flexShrink: 0, flexGrow: 0, gap: spacing.lg }}>
          <GlassPanel pad="md">
            <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("matches.upcoming.title")}</Text>
              <View style={{ backgroundColor: colors.courtLight, borderRadius: radii.pill, paddingHorizontal: spacing.sm, paddingVertical: 3 }}>
                <Text style={{ ...typography.footnote, color: colors.neon }}>{state.proposals.length}</Text>
              </View>
            </View>
            <View style={{ gap: spacing.sm }}>
              {state.proposals.slice(0, 3).map((proposal, index) => (
                <MiniMatchCard key={proposal.id} proposal={proposal} index={index} state={state} />
              ))}
            </View>
          </GlassPanel>
          <PrimaryButton
            label={t("matches.create")}
            icon={<Icon name="calendar-plus" size={16} color={colors.textOnBall as string} />}
            onPress={() => state.setFilter("all")}
          />
        </View>

        <View style={{ flex: 1, minWidth: 320, gap: spacing.lg }}>
          <GlassPanel style={{ minHeight: 300 }}>
            <View
              style={{
                alignItems: "center",
                flexDirection: "row",
                flexWrap: "wrap",
                gap: spacing.lg,
                justifyContent: "center"
              }}
            >
              <View style={{ flexBasis: 150, flexGrow: 1, minWidth: 0 }}>
                <Text style={{ ...broadcast.jersey, color: colors.neon }}>{t("matches.live.eyebrow")}</Text>
                <Text style={{ ...typography.subheadline, color: colors.textPrimary, marginTop: spacing.md }}>
                  {leftName}
                </Text>
                <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("matches.live.captainRecords")}</Text>
              </View>
              <LiveBallStage label={t("matches.live.court")} size={126} />
              <View style={{ alignItems: "flex-end", flexBasis: 150, flexGrow: 1, minWidth: 0 }}>
                <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{rightName}</Text>
                <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("matches.live.rivalValidates")}</Text>
                <Text style={{ ...broadcast.scoreboard, color: colors.neon, marginTop: spacing.md }}>{score}</Text>
              </View>
            </View>
          </GlassPanel>

          <GlassPanel pad="md">
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
              <ValidationStep number="1" label={t("matches.live.captainRecords")} status={t("matches.validation.recorded")} done />
              <ValidationStep number="2" label={t("matches.live.rivalValidates")} status={t("matches.score.pending")} active />
              <ValidationStep number="3" label={t("matches.validation.confirmed")} status={t("matches.score.pending")} />
            </View>
          </GlassPanel>

          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.lg }}>
            <GlassPanel style={{ flexBasis: 220, flexGrow: 1 }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("matches.captain.title")}</Text>
              <Text style={{ ...typography.body, color: colors.textSecondary, marginTop: spacing.xs }}>
                {t("matches.captain.body")}
              </Text>
            </GlassPanel>
            <GlassPanel style={{ flexBasis: 220, flexGrow: 1 }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("matches.stars.title")}</Text>
              <Text style={{ ...broadcast.rank, color: colors.neon, marginTop: spacing.xs }}>★★★★☆</Text>
              <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("matches.stars.hint")}</Text>
            </GlassPanel>
          </View>
        </View>

        <View style={{ width: 280, flexShrink: 0, flexGrow: 0, gap: spacing.lg }}>
          <GlassPanel pad="md">
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("matches.activity.title")}</Text>
            {state.rooms.slice(0, 3).map((room) => (
              <View key={room.id} style={{ borderBottomColor: colors.border, borderBottomWidth: 1, paddingVertical: spacing.sm }}>
                <Text style={{ ...typography.caption, color: colors.neon }}>{room.status === "validated" ? t("matches.validation.confirmed") : t("matches.validation.recorded")}</Text>
                <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{room.teamA.playerNames[0]} vs {room.teamB.playerNames[0]}</Text>
              </View>
            ))}
          </GlassPanel>
          <GlassPanel pad="md">
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("matches.validate.title")}</Text>
            <Text style={{ ...broadcast.scoreboard, color: colors.neon, marginTop: spacing.sm }}>{score}</Text>
            <PrimaryButton label={t("matches.validate.title")} onPress={() => primaryRoom && state.openRoom(primaryRoom)} style={{ marginTop: spacing.md }} />
          </GlassPanel>
        </View>
      </View>
    </View>
  );
}

function MatchStat({ icon, value, label }: { icon: IconName; value: string | number; label: string }) {
  return (
    <GlassPanel pad="md" style={{ minWidth: 138 }}>
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
        <Icon name={icon} size={20} color={colors.neon as string} />
        <Text style={{ ...broadcast.stat, color: colors.textPrimary }}>{value}</Text>
      </View>
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{label}</Text>
    </GlassPanel>
  );
}

function MiniMatchCard({ proposal, index, state }: { proposal: MatchProposal; index: number; state: MatchesState }) {
  const { t, lang } = useI18n();
  const { otherPlayer, club } = resolveProposal(proposal, state);
  const isOpen = proposal.acceptedByPlayerId === null;
  return (
    <View
      style={{
        backgroundColor: index === 0 ? colors.courtLight : colors.surface,
        borderColor: index === 0 ? `${colors.neon}44` : colors.border,
        borderRadius: radii.md,
        borderWidth: 1,
        padding: spacing.md
      }}
    >
      <Text style={{ ...typography.footnote, color: colors.neon }}>{formatProposalDate(proposal, lang)}</Text>
      <Text style={{ ...typography.caption, color: colors.textPrimary, marginTop: 4 }} numberOfLines={1}>
        {isOpen ? t("matches.row.open") : t("matches.row.vs").replace("{name}", otherPlayer?.name ?? t("matches.row.rivalFallback"))}
      </Text>
      <Text style={{ ...typography.footnote, color: colors.textSecondary }} numberOfLines={1}>{club?.name ?? t("matches.row.clubFallback")} · {proposal.format} · {t("common.court").replace("{court}", String(proposal.court))}</Text>
    </View>
  );
}

function ValidationStep({
  number,
  label,
  status,
  done,
  active
}: {
  number: string;
  label: string;
  status: string;
  done?: boolean;
  active?: boolean;
}) {
  return (
    <View
      style={{
        backgroundColor: active ? colors.goldSoft : done ? colors.courtLight : colors.surface,
        borderColor: active ? `${colors.gold}66` : done ? `${colors.neon}44` : colors.border,
        borderRadius: radii.lg,
        borderWidth: 1,
        flexBasis: 168,
        flexGrow: 1,
        minWidth: 168,
        padding: spacing.md
      }}
    >
      <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
        <View
          style={{
            alignItems: "center",
            borderColor: active ? colors.gold : colors.neon,
            borderRadius: radii.pill,
            borderWidth: 2,
            height: 32,
            justifyContent: "center",
            width: 32
          }}
        >
          <Text style={{ ...broadcast.jersey, color: active ? colors.gold : colors.neon }}>{number}</Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ ...typography.caption, color: colors.textPrimary }}>{label}</Text>
          <Text style={{ ...typography.footnote, color: active ? colors.gold : done ? colors.neon : colors.textSecondary }}>{status}</Text>
        </View>
      </View>
    </View>
  );
}

function MatchOpsHero({ state }: { state: MatchesState }) {
  const { t } = useI18n();
  const pendingValidation = state.rooms.filter((room) => room.status === "awaiting_validation").length;
  const validated = state.rooms.filter((room) => room.status === "validated").length;
  const averageStars = state.rooms.flatMap((room) => room.reviews).length
    ? (
        state.rooms.flatMap((room) => room.reviews).reduce((total, review) => total + review.stars, 0) /
        state.rooms.flatMap((room) => room.reviews).length
      ).toFixed(1)
    : "0.0";

  return (
    <ConceptHero
      kicker="MATCH CONTROL"
      title={t("matches.ops.title")}
      body={t("matches.ops.body")}
      centerLabel={t("matches.ops.center").replace("{count}", String(state.actionCount))}
      metrics={[
        { icon: "pencil", label: t("matches.ops.rooms"), value: state.rooms.length },
        { icon: "check-badge", label: t("matches.ops.toValidate"), value: pendingValidation },
        { icon: "star", label: t("matches.ops.stars"), value: `${averageStars}/5` }
      ]}
      chips={[
        { icon: "pencil", label: t("matches.captain.title"), value: t("matches.ops.captainValue") },
        { icon: "check-badge", label: t("matches.ops.rival"), value: t("matches.ops.rivalValue").replace("{count}", String(pendingValidation)) },
        { icon: "trophy", label: t("matches.filters.accepted"), value: `${validated}` }
      ]}
    />
  );
}

// ---------------------------------------------------------------------------
// Resultados / salas del partido
// ---------------------------------------------------------------------------

function RoomsList({ state, columns }: { state: MatchesState; columns: 1 | 2 }) {
  if (state.rooms.length === 0) return <EmptyState filter="results" />;

  if (columns === 2) {
    return (
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>
        {state.rooms.map((room, index) => (
          <View key={room.id} style={{ flexBasis: "48%", flexGrow: 1, minWidth: 320 }}>
            <MatchRoomCard
              room={room}
              index={index}
              currentPlayerId={state.currentPlayer?.id}
              clubName={state.clubs.find((c) => c.id === room.clubId)?.name}
              onOpen={state.openRoom}
            />
          </View>
        ))}
      </View>
    );
  }

  return (
    <View style={{ gap: spacing.sm }}>
      {state.rooms.map((room, index) => (
        <MatchRoomCard
          key={room.id}
          room={room}
          index={index}
          currentPlayerId={state.currentPlayer?.id}
          clubName={state.clubs.find((c) => c.id === room.clubId)?.name}
          onOpen={state.openRoom}
        />
      ))}
    </View>
  );
}

function RoomModal({ state }: { state: MatchesState }) {
  const room = state.activeRoom;
  return (
    <ModalSheet visible={!!room} onClose={state.closeRoom} maxWidth={560}>
      {room ? (
        <MatchRoomSheet
          room={room}
          currentPlayerId={state.currentPlayer?.id}
          clubName={state.clubs.find((c) => c.id === room.clubId)?.name}
          onRoomChange={state.updateRoom}
          onClose={state.closeRoom}
        />
      ) : null}
    </ModalSheet>
  );
}

function ActionBanner({ count, onPress }: { count: number; onPress: () => void }) {
  const { t } = useI18n();
  return (
    <Animated.View entering={FadeIn.springify().damping(18)}>
      <Card
        variant="elevated"
        style={{ borderColor: `${colors.spotlightDim}66`, boxShadow: undefined }}
      >
        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
          <View
            style={{
              alignItems: "center",
              backgroundColor: colors.spotlight,
              borderRadius: radii.md,
              height: 42,
              justifyContent: "center",
              width: 42
            }}
          >
            <Icon name="check-badge" size={22} color={colors.textOnBall as string} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>
              {(count === 1 ? t("matches.banner.one") : t("matches.banner.many")).replace("{count}", String(count))}
            </Text>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
              {t("matches.banner.body")}
            </Text>
          </View>
          <PrimaryButton label={t("matches.banner.view")} variant="outline" fullWidth={false} onPress={onPress} style={{ height: 38, paddingHorizontal: spacing.md }} />
        </View>
      </Card>
    </Animated.View>
  );
}

// ---------------------------------------------------------------------------
// Filas de propuestas (invitaciones)
// ---------------------------------------------------------------------------

function MatchRowWeb({
  proposal,
  index,
  state
}: {
  proposal: MatchProposal;
  index: number;
  state: MatchesState;
}) {
  const { t, lang } = useI18n();
  const { otherPlayer, club } = resolveProposal(proposal, state);
  const isOpen = proposal.acceptedByPlayerId === null;
  const canAccept = proposal.status === "proposed" && proposal.fromPlayerId !== state.currentPlayer?.id;
  const canCancel = proposal.fromPlayerId === state.currentPlayer?.id && proposal.status !== "declined";
  const canRelease = proposal.acceptedByPlayerId === state.currentPlayer?.id && proposal.status === "accepted";
  const updating = state.updatingId === proposal.id;
  const isCompatible = state.currentPlayer ? isProposalLevelAccepted(proposal, state.currentPlayer) : false;
  const requested = state.joinRequests.some((item) => item.matchId === proposal.id && item.requesterId === state.currentPlayer?.id && item.status !== "declined");
  const incomingRequests = state.joinRequests.filter((item) => item.matchId === proposal.id && item.status === "pending");

  return (
    <Animated.View entering={FadeIn.delay(index * 40).springify()}>
      <Card pad="lg">
        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.lg }}>
          <Avatar name={otherPlayer?.name ?? "?"} size={56} />
          <View style={{ flex: 1, gap: 4 }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary, flex: 1, fontSize: 18 }}>
                {isOpen ? t("matches.row.open") : (otherPlayer?.name ?? t("matches.row.playerFallback"))}
              </Text>
              <StatusBadge status={proposal.status} />
            </View>
            <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14 }}>
              {formatProposalDate(proposal, lang)} · {t("common.court").replace("{court}", String(proposal.court))}
            </Text>
            <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14 }}>
              {club?.name} · {proposal.format} · {t("matches.row.level").replace("{level}", levelLabel(proposal.division))}
            </Text>
            {club?.address ? (
              <Text style={{ ...typography.footnote, color: colors.textTertiary }} numberOfLines={1}>
                {club.address}
              </Text>
            ) : null}
            {proposal.message ? (
              <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14 }} numberOfLines={2}>
                {proposal.message}
              </Text>
            ) : null}
          </View>
          <View style={{ alignItems: "flex-end", gap: spacing.sm, minWidth: 160 }}>
            {canAccept ? (
              <>
                <PrimaryButton
                  label={requested ? t("matches.join.sent") : updating ? t("matches.join.sending") : isCompatible ? t("matches.join.request") : t("matches.join.incompatible")}
                  fullWidth={false}
                  icon={<Icon name="check" size={16} color={colors.textOnBrand as string} />}
                  onPress={() => state.requestJoin(proposal.id)}
                  disabled={!isCompatible || updating || requested}
                  style={{ minWidth: 140 }}
                />
                {!isOpen ? (
                  <PrimaryButton
                    label={t("matches.join.decline")}
                    variant="outline"
                    fullWidth={false}
                    onPress={() => state.setStatus(proposal.id, "declined")}
                    style={{ minWidth: 140 }}
                  />
                ) : null}
              </>
            ) : null}
            {canCancel ? (
              <PrimaryButton
                label={updating ? t("matches.cancel.cancelling") : t("matches.cancel.label")}
                variant="outline"
                fullWidth={false}
                disabled={updating}
                onPress={() => confirmProposalChange("cancel", proposal.id, state, t)}
                style={{ minWidth: 140 }}
              />
            ) : null}
            {canRelease ? (
              <PrimaryButton
                label={updating ? t("matches.release.releasing") : t("matches.release.label")}
                variant="outline"
                fullWidth={false}
                disabled={updating}
                onPress={() => confirmProposalChange("release", proposal.id, state, t)}
                style={{ minWidth: 140 }}
              />
            ) : null}
            {club && proposal.status === "accepted" ? (
              <Chip
                label={t("matches.row.directions")}
                icon={<WazeLogo size={14} color={colors.court} />}
                onPress={() => openInWaze(club.latitude, club.longitude, club.name)}
              />
            ) : null}
          </View>
        </View>
        {proposal.fromPlayerId === state.currentPlayer?.id && isOpen ? <JoinRequestsPanel requests={incomingRequests} state={state} /> : null}
      </Card>
    </Animated.View>
  );
}

function MatchRowNative({
  proposal,
  index,
  state
}: {
  proposal: MatchProposal;
  index: number;
  state: MatchesState;
}) {
  const { t, lang } = useI18n();
  const { otherPlayer, club } = resolveProposal(proposal, state);
  const statusIcon = statusIconFor(proposal.status);
  const isOpen = proposal.acceptedByPlayerId === null;
  const canAccept = proposal.status === "proposed" && proposal.fromPlayerId !== state.currentPlayer?.id;
  const canCancel = proposal.fromPlayerId === state.currentPlayer?.id && proposal.status !== "declined";
  const canRelease = proposal.acceptedByPlayerId === state.currentPlayer?.id && proposal.status === "accepted";
  const updating = state.updatingId === proposal.id;
  const isCompatible = state.currentPlayer ? isProposalLevelAccepted(proposal, state.currentPlayer) : false;
  const requested = state.joinRequests.some((item) => item.matchId === proposal.id && item.requesterId === state.currentPlayer?.id && item.status !== "declined");
  const incomingRequests = state.joinRequests.filter((item) => item.matchId === proposal.id && item.status === "pending");

  return (
    <Animated.View entering={SlideInRight.delay(index * 50).springify().damping(18)}>
      <Card
        variant="elevated"
        style={{
          borderColor: proposal.status === "accepted" ? `${colors.court}33` : colors.border
        }}
      >
        <View style={{ alignItems: "flex-start", flexDirection: "row", gap: spacing.md }}>
          <Avatar name={otherPlayer?.name ?? "?"} size={48} />
          <View style={{ flex: 1, gap: 4 }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
              <Text style={{ ...typography.subheadline, color: colors.textPrimary, flex: 1 }} numberOfLines={1}>
                {isOpen ? t("matches.row.open") : (otherPlayer?.name ?? t("matches.row.playerFallback"))}
              </Text>
              <StatusBadge status={proposal.status} />
            </View>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
              <Icon name={statusIcon} size={12} color={colors.textTertiary as string} />
              <Text style={{ ...typography.footnote, color: colors.textSecondary }} numberOfLines={1}>
                {club?.name} · {proposal.format} · {t("common.court").replace("{court}", String(proposal.court))}
              </Text>
            </View>
            <Text style={{ ...typography.footnote, color: colors.textTertiary }}>
              {formatProposalDate(proposal, lang)} · {levelLabel(proposal.division)}
            </Text>
            {club?.address ? (
              <Text style={{ ...typography.footnote, color: colors.textTertiary }} numberOfLines={1}>
                {club.address}
              </Text>
            ) : null}
          </View>
        </View>

        {proposal.message ? (
          <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14, lineHeight: 20 }} numberOfLines={2}>
            {proposal.message}
          </Text>
        ) : null}

        {canAccept ? (
          <View style={{ flexDirection: "row", gap: spacing.sm }}>
            <View style={{ flex: 1 }}>
              <PrimaryButton
                label={requested ? t("matches.join.sent") : updating ? t("matches.join.sending") : isCompatible ? t("matches.join.request") : t("matches.join.incompatible")}
                icon={<Icon name="check" size={16} color={colors.textOnBrand as string} />}
                onPress={() => state.requestJoin(proposal.id)}
                disabled={!isCompatible || updating || requested}
              />
            </View>
            {!isOpen ? (
              <View style={{ flex: 1 }}>
                <PrimaryButton label={t("matches.join.decline")} variant="outline" onPress={() => state.setStatus(proposal.id, "declined")} />
              </View>
            ) : null}
          </View>
        ) : null}

        {canCancel ? (
          <PrimaryButton
            label={updating ? t("matches.cancel.cancelling") : t("matches.cancel.label")}
            variant="outline"
            disabled={updating}
            onPress={() => confirmProposalChange("cancel", proposal.id, state, t)}
          />
        ) : null}

        {canRelease ? (
          <PrimaryButton
            label={updating ? t("matches.release.releasing") : t("matches.release.label")}
            variant="outline"
            disabled={updating}
            onPress={() => confirmProposalChange("release", proposal.id, state, t)}
          />
        ) : null}

        {club && proposal.status === "accepted" ? (
          <Chip
            label={t("common.directions")}
            icon={<WazeLogo size={19} color={colors.court} />}
            onPress={() => openInWaze(club.latitude, club.longitude, club.name)}
          />
        ) : null}
        {proposal.fromPlayerId === state.currentPlayer?.id && isOpen ? <JoinRequestsPanel requests={incomingRequests} state={state} /> : null}
      </Card>
    </Animated.View>
  );
}

function JoinRequestsPanel({ requests, state }: { requests: MatchJoinRequest[]; state: MatchesState }) {
  const { t } = useI18n();
  if (requests.length === 0) {
    return (
      <View style={{ alignItems: "center", backgroundColor: colors.surfaceCourt, borderRadius: radii.md, flexDirection: "row", gap: spacing.sm, padding: spacing.sm }}>
        <Icon name="users" size={16} color={colors.textTertiary as string} />
        <Text style={{ ...typography.footnote, color: colors.textTertiary }}>{t("matches.requests.empty")}</Text>
      </View>
    );
  }
  return (
    <View style={{ borderTopColor: colors.border, borderTopWidth: 1, gap: spacing.sm, paddingTop: spacing.md }}>
      <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("matches.requests.title").replace("{count}", String(requests.length))}</Text>
      {requests.map((request) => {
        const busy = state.updatingId === request.id;
        return (
          <View key={request.id} style={{ alignItems: "center", backgroundColor: colors.surfaceCourt, borderRadius: radii.md, flexDirection: "row", flexWrap: "wrap", gap: spacing.sm, padding: spacing.sm }}>
            <Avatar name={request.requesterName} size={36} />
            <View style={{ flex: 1, minWidth: 130 }}>
              <Text style={{ ...typography.caption, color: colors.textPrimary }}>{request.requesterName}</Text>
              <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("matches.row.level").replace("{level}", levelLabel(request.requesterLevel))}</Text>
            </View>
            <PrimaryButton label={busy ? "…" : t("matches.requests.accept")} fullWidth={false} disabled={busy} onPress={() => state.respondJoin(request, true)} style={{ height: 38 }} />
            <PrimaryButton label={t("matches.requests.reject")} variant="outline" fullWidth={false} disabled={busy} onPress={() => state.respondJoin(request, false)} style={{ height: 38 }} />
          </View>
        );
      })}
    </View>
  );
}

function isProposalLevelAccepted(proposal: MatchProposal, player: Player) {
  return proposal.acceptedLevels?.length
    ? proposal.acceptedLevels.includes(player.level)
    : isLevelCompatible(proposal.division, player.level);
}

// ---------------------------------------------------------------------------
// Estado
// ---------------------------------------------------------------------------

type MatchesState = ReturnType<typeof useMatchesState>;

function useMatchesState() {
  const { user, isConfigured } = useAuth();
  const { t } = useI18n();
  const playerId = isConfigured && user ? user.uid : "me";
  const [proposals, setProposals] = useState<MatchProposal[]>([]);
  const [players, setPlayers] = useState<Player[]>([]);
  const [clubs, setClubs] = useState<Club[]>([]);
  const [currentPlayer, setCurrentPlayer] = useState<Player | null>(null);
  const [rooms, setRooms] = useState<MatchRoom[]>([]);
  const [joinRequests, setJoinRequests] = useState<MatchJoinRequest[]>([]);
  const [activeRoomId, setActiveRoomId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [filter, setFilter] = useState<MatchFilter>("all");

  useEffect(() => {
    let cancelled = false;
    Promise.all([getHomeData(), getMatchRooms(playerId)])
      .then(([home, matchRooms]) => {
        if (cancelled) return;
        setError(null);
        setProposals(home.proposals);
        setClubs(home.clubs);
        setCurrentPlayer(home.currentPlayer);
        setPlayers(home.players);
        setRooms(matchRooms);
        setJoinRequests(home.joinRequests);
      })
      .catch((reason: unknown) => {
        if (!cancelled) setError(describeMatchesError(reason, t("matches.error.fallback")));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [playerId]);

  const setStatus = async (id: string, status: MatchProposal["status"]) => {
    if (updatingId) return;
    setUpdatingId(id);
    try {
      if (process.env.EXPO_OS === "ios") Haptics.selectionAsync();
      await updateProposalStatus(id, status);
      const fresh = await getHomeData();
      setProposals(fresh.proposals);
      setError(null);
    } catch (reason) {
      Alert.alert(t("matches.alert.updateFailed"), describeMatchesError(reason, t("matches.error.fallback")));
    } finally {
      setUpdatingId(null);
    }
  };

  /** Recarga completa (pull-to-refresh) sin tocar el estado de `loading`. */
  const refresh = async () => {
    try {
      const [home, matchRooms] = await Promise.all([getHomeData(), getMatchRooms(playerId)]);
      setProposals(home.proposals);
      setClubs(home.clubs);
      setCurrentPlayer(home.currentPlayer);
      setPlayers(home.players);
      setRooms(matchRooms);
      setJoinRequests(home.joinRequests);
      setError(null);
    } catch (reason) {
      const message = describeMatchesError(reason, t("matches.error.fallback"));
      setError(message);
      throw reason;
    }
  };

  const updateRoom = (updated: MatchRoom) => {
    setRooms((prev) => prev.map((room) => (room.id === updated.id ? updated : room)));
  };

  const requestJoin = async (matchId: string) => {
    if (updatingId) return;
    setUpdatingId(matchId);
    try {
      const request = await requestMatchJoin(matchId);
      setJoinRequests((current) => [...current.filter((item) => item.id !== request.id), request]);
      Alert.alert(t("matches.join.sent"), t("matches.alert.sentBody"));
    } catch (reason) {
      Alert.alert(t("matches.alert.requestFailed"), describeMatchesError(reason, t("matches.error.fallback")));
    } finally {
      setUpdatingId(null);
    }
  };

  const respondJoin = async (request: MatchJoinRequest, accept: boolean) => {
    if (updatingId) return;
    setUpdatingId(request.id);
    try {
      await respondToMatchJoinRequest(request, accept);
      const fresh = await getHomeData();
      setProposals(fresh.proposals);
      setJoinRequests(fresh.joinRequests);
      Alert.alert(
        accept ? t("matches.alert.confirmed") : t("matches.alert.rejected"),
        accept ? t("matches.alert.confirmedBody").replace("{name}", request.requesterName) : t("matches.alert.rejectedBody")
      );
    } catch (reason) {
      Alert.alert(t("matches.alert.respondFailed"), describeMatchesError(reason, t("matches.error.fallback")));
    } finally {
      setUpdatingId(null);
    }
  };

  const counts = useMemo(
    () => ({
      all: proposals.length,
      proposed: proposals.filter((p) => p.status === "proposed").length,
      accepted: proposals.filter((p) => p.status === "accepted").length,
      declined: proposals.filter((p) => p.status === "declined").length
    }),
    [proposals]
  );

  const actionCount = useMemo(
    () => rooms.filter((room) => roomAffordances(room, playerId).pendingAction !== null).length,
    [rooms, playerId]
  );

  const filtered = useMemo(() => {
    if (filter === "all") return proposals;
    if (filter === "results") return [];
    return proposals.filter((p) => p.status === filter);
  }, [filter, proposals]);

  const activeRoom = rooms.find((room) => room.id === activeRoomId) ?? null;

  return {
    proposals,
    players,
    clubs,
    currentPlayer,
    rooms,
    joinRequests,
    loading,
    error,
    updatingId,
    filter,
    setFilter,
    counts,
    actionCount,
    filtered,
    setStatus,
    requestJoin,
    respondJoin,
    refresh,
    updateRoom,
    activeRoom,
    openRoom: (room: MatchRoom) => setActiveRoomId(room.id),
    closeRoom: () => setActiveRoomId(null)
  };
}

function resolveProposal(proposal: MatchProposal, state: MatchesState) {
  const isOpen = proposal.acceptedByPlayerId === null;
  const otherPlayerId = isOpen
    ? undefined
    : proposal.acceptedByPlayerId === state.currentPlayer?.id
      ? proposal.fromPlayerId
      : proposal.acceptedByPlayerId ?? undefined;
  const otherPlayer = otherPlayerId ? state.players.find((player) => player.id === otherPlayerId) : undefined;
  const club = state.clubs.find((item) => item.id === proposal.clubId);
  return { otherPlayer, club, isOpen };
}

function EmptyState({ filter }: { filter: MatchFilter }) {
  const { t } = useI18n();
  const messages: Record<MatchFilter, { title: string; body: string; icon: IconName }> = {
    all: { title: t("matches.empty.all.title"), body: t("matches.empty.all.body"), icon: "calendar-plus" },
    proposed: { title: t("matches.empty.proposed.title"), body: t("matches.empty.proposed.body"), icon: "clock" },
    accepted: { title: t("matches.empty.accepted.title"), body: t("matches.empty.accepted.body"), icon: "check-badge" },
    results: {
      title: t("matches.empty.results.title"),
      body: t("matches.empty.results.body"),
      icon: "trophy"
    }
  };
  const copy = messages[filter];

  return (
    <Card>
      <View style={{ alignItems: "center", gap: spacing.sm, paddingVertical: spacing.xl }}>
        <View
          style={{
            alignItems: "center",
            backgroundColor: colors.courtLight,
            borderRadius: radii.xl,
            height: 64,
            justifyContent: "center",
            width: 64
          }}
        >
          <Icon name={copy.icon} size={30} color={colors.court as string} />
        </View>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary, textAlign: "center" }}>
          {copy.title}
        </Text>
        <Text style={{ ...typography.body, color: colors.textSecondary, fontSize: 14, textAlign: "center" }}>
          {copy.body}
        </Text>
      </View>
    </Card>
  );
}

function statusIconFor(status: MatchProposal["status"]): IconName {
  if (status === "accepted") return "check-badge";
  if (status === "declined") return "sign-out";
  return "clock";
}

function formatProposalDate(proposal: MatchProposal, lang: string) {
  const date = new Date(proposal.startsAt);
  const day = date.toLocaleDateString(lang, { weekday: "long", day: "numeric", month: "short" });
  return `${day} · ${proposal.reservationTime.replace("-", "–")}`;
}

function confirmProposalChange(action: "cancel" | "release", id: string, state: MatchesState, t: (key: string) => string) {
  const cancelling = action === "cancel";
  Alert.alert(
    cancelling ? t("matches.confirm.cancelTitle") : t("matches.confirm.releaseTitle"),
    cancelling
      ? t("matches.confirm.cancelBody")
      : t("matches.confirm.releaseBody"),
    [
      { text: t("matches.confirm.keep"), style: "cancel" },
      {
        text: cancelling ? t("matches.cancel.label") : t("matches.confirm.releaseAction"),
        style: "destructive",
        onPress: () => void state.setStatus(id, cancelling ? "declined" : "proposed")
      }
    ]
  );
}

function describeMatchesError(error: unknown, fallback: string) {
  if (error instanceof Error) return error.message;
  return fallback;
}
