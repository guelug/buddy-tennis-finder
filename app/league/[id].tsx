import { useCallback, useEffect, useState } from "react";
import { Alert, Text, View } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { Avatar } from "@/components/avatar";
import { Card } from "@/components/card";
import { DivisionBadge } from "@/components/division-badge";
import { Icon } from "@/components/icon";
import { LoadingView } from "@/components/loading-view";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { GlassPanel, LiveBackground, bgLeaguesLive, bgLeaguesLiveLight } from "@/components/live-visuals";
import { findPublicLeague } from "@/data/competition-hub";
import { DIVISION_LABELS, DIVISION_META } from "@/data/rankings";
import { useAuth } from "@/lib/firebase-auth";
import { getPublicLeagueMembers, leavePublicLeague } from "@/lib/firestore";
import { useI18n } from "@/lib/i18n";
import { broadcast, colors, radii, shadows, spacing, typography } from "@/theme";
import type { Player } from "@/types";

/**
 * Vista de "mi liga": inscritos reales, clasificación y reglas. Los puntos
 * siguen a cero hasta que exista el backend de resultados validados, así que
 * la tabla lo dice de forma explícita en vez de inventar posiciones.
 */
export default function PublicLeagueScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { user, isConfigured } = useAuth();
  const { t } = useI18n();
  const league = findPublicLeague(id);
  const [members, setMembers] = useState<Player[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [leaving, setLeaving] = useState(false);

  const load = useCallback(async () => {
    if (!league || !isConfigured) {
      setLoading(false);
      return;
    }
    setError(null);
    try {
      setMembers(await getPublicLeagueMembers(league.id));
    } catch {
      setError(t("league.detail.loadError"));
    } finally {
      setLoading(false);
    }
  }, [league, isConfigured, t]);

  useEffect(() => { void load(); }, [load]);

  if (!league) {
    return (
      <LiveBackground source={bgLeaguesLive} lightSource={bgLeaguesLiveLight} overlay={0.45}>
        <ScreenShell topSafe>
          <Card>
            <Text style={{ ...typography.headline, color: colors.textPrimary, textAlign: "center" }}>
              {t("league.detail.notFound")}
            </Text>
          </Card>
        </ScreenShell>
      </LiveBackground>
    );
  }

  if (loading) return <LoadingView />;

  const meIndex = members.findIndex((member) => member.id === user?.uid);
  const joined = meIndex >= 0;
  const meta = DIVISION_META[league.division];

  const leave = async () => {
    if (!user) return;
    setLeaving(true);
    try {
      await leavePublicLeague(user.uid, league.id);
      setMembers((current) => current.filter((member) => member.id !== user.uid));
      // La pantalla puede abrirse desde un enlace directo, sin historial detrás.
      if (router.canGoBack()) router.back();
      else router.replace("/liga");
    } catch (reason) {
      Alert.alert(t("league.joinError"), reason instanceof Error ? reason.message : t("league.inviteError"));
    } finally {
      setLeaving(false);
    }
  };

  return (
    <LiveBackground source={bgLeaguesLive} lightSource={bgLeaguesLiveLight} overlay={0.45}>
      <ScreenShell onRefresh={load}>
        <Card variant="premium" style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, boxShadow: shadows.courtGlow }}>
          <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
            <Text style={{ ...broadcast.jersey, color: colors.neon, fontSize: 12, letterSpacing: 1.6 }}>
              {t("league.detail.eyebrow")}
            </Text>
            <DivisionBadge division={league.division} size={30} active />
          </View>
          <Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 24, marginTop: 4 }}>{league.name}</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
            {league.season} · {DIVISION_LABELS[league.division]} · {meta.circuit}
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm, marginTop: spacing.sm }}>
            <Stat label={t("league.detail.membersLabel")} value={`${members.length}/${league.capacity}`} />
            <Stat label={t("ranking.status")} value={t("ranking.leagueStatus.open")} />
            <Stat label={t("league.detail.yourPosition")} value={joined ? `#${meIndex + 1}` : "—"} />
          </View>
        </Card>

        {error ? (
          <Card>
            <Text selectable style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>{error}</Text>
            <PrimaryButton label={t("common.retry")} onPress={() => void load()} />
          </Card>
        ) : null}

        <GlassPanel pad="md">
          <Text style={{ ...typography.subheadline, color: colors.textPrimary, marginBottom: spacing.sm }}>
            {t("league.detail.standings")}
          </Text>
          <View style={{ flexDirection: "row", gap: spacing.sm, paddingBottom: spacing.sm }}>
            <Text style={{ ...typography.footnote, color: colors.textTertiary, width: 28 }}>#</Text>
            <Text style={{ ...typography.footnote, color: colors.textTertiary, flex: 1 }}>{t("ranking.table.player")}</Text>
            <Text style={{ ...typography.footnote, color: colors.textTertiary, width: 60, textAlign: "center" }}>{t("ranking.table.wl")}</Text>
            <Text style={{ ...typography.footnote, color: colors.textTertiary, width: 62, textAlign: "right" }}>{t("ranking.table.points")}</Text>
          </View>
          {members.length ? members.map((member, index) => (
            <View
              key={member.id}
              style={{
                alignItems: "center",
                backgroundColor: member.id === user?.uid ? colors.courtLight : "transparent",
                borderTopColor: colors.border,
                borderTopWidth: 1,
                flexDirection: "row",
                gap: spacing.sm,
                paddingHorizontal: spacing.xs,
                paddingVertical: spacing.sm
              }}
            >
              <Text style={{ ...broadcast.stat, color: colors.textTertiary, width: 28 }}>{index + 1}</Text>
              <Avatar name={member.name} size={32} />
              <View style={{ flex: 1, minWidth: 0 }}>
                <Text numberOfLines={1} style={{ ...typography.caption, color: colors.textPrimary, fontWeight: "800" }}>
                  {member.name}{member.id === user?.uid ? t("ranking.youSuffix") : ""}
                </Text>
                <Text numberOfLines={1} style={{ ...typography.footnote, color: colors.textTertiary }}>{member.city}</Text>
              </View>
              <Text style={{ ...typography.caption, color: colors.textSecondary, width: 60, textAlign: "center" }}>—</Text>
              <Text style={{ ...broadcast.stat, color: colors.court, width: 62, textAlign: "right" }}>0</Text>
            </View>
          )) : (
            <Text style={{ ...typography.body, color: colors.textSecondary, paddingVertical: spacing.lg, textAlign: "center" }}>
              {t("league.detail.empty")}
            </Text>
          )}
          <Text style={{ ...typography.footnote, color: colors.textTertiary, marginTop: spacing.sm }}>
            {t("league.detail.pointsNote")}
          </Text>
        </GlassPanel>

        <Card style={{ backgroundColor: colors.infoBg, borderColor: `${colors.info}44` }}>
          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
            <Icon name="trophy" size={20} color={colors.info as string} />
            <View style={{ flex: 1 }}>
              <Text style={{ ...typography.caption, color: colors.textPrimary }}>{t("league.detail.rulesTitle")}</Text>
              <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("league.detail.rulesBody")}</Text>
            </View>
          </View>
        </Card>

        <View style={{ gap: spacing.sm }}>
          <PrimaryButton
            label={t("league.detail.findRivals")}
            icon={<Icon name="tennis" size={16} color={colors.textOnBrand as string} />}
            onPress={() => router.push("/")}
          />
          {joined ? (
            <PrimaryButton
              label={leaving ? t("league.detail.leaving") : t("ranking.publicLeague.leave")}
              variant="outline"
              disabled={leaving}
              onPress={() => void leave()}
            />
          ) : null}
        </View>
      </ScreenShell>
    </LiveBackground>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.md, borderWidth: 1, flexGrow: 1, minWidth: 96, padding: spacing.sm }}>
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{label}</Text>
      <Text style={{ ...broadcast.stat, color: colors.textPrimary, fontSize: 20 }}>{value}</Text>
    </View>
  );
}
