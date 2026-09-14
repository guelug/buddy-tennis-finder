import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Text, View } from "react-native";
import Animated, { FadeIn, FadeInUp } from "react-native-reanimated";
import { Icon, type IconName } from "@/components/icon";
import { GlassPanel, LiveBackground } from "@/components/live-visuals";
import { LevelProgress, StreakPill } from "@/components/level-progress";
import { MedalGrid } from "@/components/medal-grid";
import { ProgressRings, RingLegend } from "@/components/progress-rings";
import { ScreenShell } from "@/components/screen-shell";
import { WeeklyGoalEditor } from "@/components/weekly-goal-editor";
import { useAuth } from "@/lib/firebase-auth";
import { summarizeProgress, nextMilestone } from "@/lib/gamification";
import { useI18n } from "@/lib/i18n";
import { getMatchRooms } from "@/lib/match-room";
import { useWeeklyGoals } from "@/lib/weekly-goals";
import { broadcast, colors, radii, spacing, typography } from "@/theme";
import { MatchRoom } from "@/types";

/**
 * Pantalla de progreso: anillos de la semana, nivel, estadísticas y medallas.
 * Se alimenta de las mismas salas de partido que ya usa el perfil, así que no
 * añade lecturas nuevas a Firestore.
 */
export default function ProgressScreen() {
  const { user, isConfigured } = useAuth();
  const { t } = useI18n();
  const { goals, setGoal, reset } = useWeeklyGoals();
  const [rooms, setRooms] = useState<MatchRoom[] | null>(null);

  const playerId = isConfigured && user ? user.uid : "me";

  useEffect(() => {
    let active = true;
    getMatchRooms(playerId)
      .then((next) => {
        if (active) setRooms(next);
      })
      .catch(() => {
        if (active) setRooms([]);
      });
    return () => {
      active = false;
    };
  }, [playerId]);

  const summary = useMemo(
    () => summarizeProgress(rooms ?? [], playerId, new Date(), goals),
    [rooms, playerId, goals]
  );
  const milestone = useMemo(() => nextMilestone(summary), [summary]);

  const refresh = async () => {
    await getMatchRooms(playerId, { fresh: true }).then(setRooms).catch(() => {});
  };

  if (rooms === null) {
    return (
      <View style={{ alignItems: "center", backgroundColor: colors.background, flex: 1, justifyContent: "center" }}>
        <ActivityIndicator size="large" color={colors.neon} />
      </View>
    );
  }

  const { stats, week, level, medals } = summary;

  return (
    <LiveBackground overlay={0.52}>
      <ScreenShell keyboardAware={false} onRefresh={refresh}>
        {/* Anillos de la semana */}
        <Animated.View entering={FadeInUp.springify().damping(20)}>
          <GlassPanel>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.lg }}>
              <ProgressRings
                rings={week.rings}
                size={150}
                center={
                  <View style={{ alignItems: "center" }}>
                    <Text style={{ ...broadcast.stat, color: colors.textPrimary, fontSize: 26 }}>
                      {week.rings.filter((ring) => ring.closed).length}/3
                    </Text>
                    <Text style={{ ...typography.footnote, color: colors.textTertiary, fontSize: 9 }}>
                      {t("progress.rings.closed")}
                    </Text>
                  </View>
                }
              />
              <View style={{ flex: 1, gap: spacing.sm }}>
                <Text style={{ ...broadcast.jersey, color: colors.textSecondary, fontSize: 10, letterSpacing: 1.4 }}>
                  {t("progress.week.kicker")}
                </Text>
                <RingLegend rings={week.rings} compact />
              </View>
            </View>

            {week.allClosed ? (
              <View
                style={{
                  alignItems: "center",
                  backgroundColor: colors.successBg,
                  borderColor: `${colors.success}55`,
                  borderRadius: radii.md,
                  borderWidth: 1,
                  flexDirection: "row",
                  gap: spacing.sm,
                  padding: spacing.md
                }}
              >
                <Icon name="check-badge" size={18} color={colors.success as string} />
                <Text style={{ ...typography.footnote, color: colors.textPrimary, flex: 1 }}>
                  {t("progress.week.perfect")}
                </Text>
              </View>
            ) : (
              <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
                {t("progress.week.hint")}
              </Text>
            )}
          </GlassPanel>
        </Animated.View>

        {/* Tus objetivos */}
        <Animated.View entering={FadeIn.delay(60).springify()}>
          <GlassPanel>
            <PanelTitle icon="sliders" title={t("progress.goals.title")} hint={t("progress.goals.hint")} />
            <WeeklyGoalEditor goals={goals} onChange={setGoal} onReset={reset} />
          </GlassPanel>
        </Animated.View>

        {/* Nivel */}
        <Animated.View entering={FadeIn.delay(90).springify()}>
          <GlassPanel>
            <LevelProgress level={level} />
            <StreakPill weeks={stats.weekStreak} />
          </GlassPanel>
        </Animated.View>

        {/* Estadísticas */}
        <Animated.View entering={FadeIn.delay(140).springify()}>
          <GlassPanel>
            <PanelTitle icon="zap" title={t("progress.stats.title")} hint={t("progress.stats.hint")} />
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
              <StatTile label={t("progress.stats.matches")} value={stats.matches} />
              <StatTile label={t("progress.stats.wins")} value={stats.wins} />
              <StatTile label={t("progress.stats.winRate")} value={stats.winRate === null ? "—" : `${stats.winRate}%`} />
              <StatTile label={t("progress.stats.setsWon")} value={stats.setsWon} />
              <StatTile label={t("progress.stats.bestStreak")} value={stats.bestWinStreak} />
              <StatTile label={t("progress.stats.rivals")} value={stats.rivals} />
            </View>
          </GlassPanel>
        </Animated.View>

        {/* Siguiente objetivo */}
        {milestone ? (
          <Animated.View entering={FadeIn.delay(180).springify()}>
            <GlassPanel style={{ borderColor: `${colors.accentFill}44` }}>
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
                <View
                  style={{
                    alignItems: "center",
                    backgroundColor: colors.accentFill,
                    borderRadius: radii.md,
                    height: 42,
                    justifyContent: "center",
                    width: 42
                  }}
                >
                  <Icon name="trophy" size={20} color={colors.onAccentFill as string} />
                </View>
                <View style={{ flex: 1, gap: 2 }}>
                  <Text style={{ ...broadcast.jersey, color: colors.textSecondary, fontSize: 10, letterSpacing: 1.4 }}>
                    {t("progress.next.kicker")}
                  </Text>
                  <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>
                    {t("progress.next.body")
                      .replace("{count}", String(milestone.remaining))
                      .replace("{medal}", t(`progress.medals.${milestone.id}`))}
                  </Text>
                </View>
              </View>
            </GlassPanel>
          </Animated.View>
        ) : null}

        {/* Medallas */}
        <Animated.View entering={FadeIn.delay(220).springify()}>
          <GlassPanel>
            <PanelTitle icon="trophy" title={t("progress.medals.title")} hint={t("progress.medals.hint")} />
            <MedalGrid medals={medals} />
          </GlassPanel>
        </Animated.View>
      </ScreenShell>
    </LiveBackground>
  );
}

function PanelTitle({ icon, title, hint }: { icon: IconName; title: string; hint: string }) {
  return (
    <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
      <View
        style={{
          alignItems: "center",
          backgroundColor: colors.courtLight,
          borderRadius: radii.md,
          height: 34,
          justifyContent: "center",
          width: 34
        }}
      >
        <Icon name={icon} size={16} color={colors.neon as string} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{title}</Text>
        <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{hint}</Text>
      </View>
    </View>
  );
}

function StatTile({ label, value }: { label: string; value: string | number }) {
  return (
    <View
      style={{
        backgroundColor: colors.surfaceCourt,
        borderColor: colors.border,
        borderRadius: radii.md,
        borderWidth: 1,
        flexBasis: "31%",
        flexGrow: 1,
        gap: 2,
        paddingHorizontal: spacing.sm,
        paddingVertical: spacing.md
      }}
    >
      <Text style={{ ...broadcast.stat, color: colors.textPrimary, fontSize: 20 }}>{value}</Text>
      <Text style={{ ...typography.footnote, color: colors.textSecondary, fontSize: 10 }} numberOfLines={2}>
        {label}
      </Text>
    </View>
  );
}
