import { useEffect, useState } from "react";
import { Alert, Text, View } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { Icon } from "@/components/icon";
import { LoadingView } from "@/components/loading-view";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { LiveBackground } from "@/components/live-visuals";
import { getPrivateLeague, joinPrivateLeague } from "@/lib/community";
import { useAuth } from "@/lib/firebase-auth";
import { useI18n } from "@/lib/i18n";
import { levelLabel } from "@/lib/matching";
import { shareLeagueInvite } from "@/lib/share";
import { colors, radii, spacing, typography } from "@/theme";
import type { PrivateLeague } from "@/types";

export default function PrivateLeagueScreen() {
  const { id, code } = useLocalSearchParams<{ id: string; code?: string }>();
  const { user } = useAuth();
  const { t } = useI18n();
  const [league, setLeague] = useState<PrivateLeague | null>(null);
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  useEffect(() => {
    if (!id) {
      setLoading(false);
      return;
    }
    let active = true;
    const load = async () => {
      try {
        // Las reglas no revelan una liga privada a quien aún no es miembro.
        // Con una invitación válida, el alta segura debe ocurrir antes de
        // intentar leer el documento.
        const value = code && user?.uid
          ? await joinPrivateLeague(id, code)
          : await getPrivateLeague(id);
        if (active) setLeague(value);
      } catch {
        if (active) setLeague(null);
      } finally {
        if (active) setLoading(false);
      }
    };
    void load();
    return () => { active = false; };
  }, [id, code, user?.uid]);
  if (loading) return <LoadingView />;
  if (!league) return <LiveBackground overlay={0.5}><ScreenShell><Text selectable style={{ ...typography.headline, color: colors.textPrimary }}>{t("privateLeague.notFound")}</Text></ScreenShell></LiveBackground>;
  const isMember = !!user?.uid && league.memberIds.includes(user.uid);
  const join = async () => {
    setJoining(true);
    try { setLeague(await joinPrivateLeague(league.id, code || league.inviteCode)); }
    catch (error) { Alert.alert(t("privateLeague.joinErrorTitle"), error instanceof Error ? error.message : t("privateLeague.joinErrorBody")); }
    finally { setJoining(false); }
  };
  return <LiveBackground overlay={0.44}><ScreenShell><View style={{ alignItems: "center", gap: spacing.md, paddingTop: spacing.xxl }}><View style={{ alignItems: "center", backgroundColor: colors.courtLight, borderColor: `${colors.neon}66`, borderRadius: 999, borderWidth: 1, height: 92, justifyContent: "center", width: 92 }}><Icon name="trophy" size={44} color={colors.neon as string} /></View><Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 34, textAlign: "center" }}>{league.name}</Text><Text style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>{league.description}</Text></View><View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}><Row label={t("privateLeagues.level")} value={levelLabel(league.division)} /><Row label={t("privateLeagues.format")} value={league.format === "doubles" ? t("privateLeagues.doubles") : t("privateLeagues.singles")} /><Row label={t("privateLeague.members")} value={t("privateLeague.membersValue").replace("{count}", String(league.memberIds.length)).replace("{total}", String(league.maxMembers))} />{isMember ? <Row label={t("privateLeague.code")} value={league.inviteCode} /> : null}</View>{isMember ? <PrimaryButton label={t("privateLeague.invite")} icon={<Icon name="send" size={18} color={colors.textOnBrand as string} />} onPress={() => void shareLeagueInvite(league, user?.displayName || t("privateLeague.friend"))} /> : <PrimaryButton label={joining ? t("privateLeague.joining") : t("privateLeague.join")} disabled={joining || !code} onPress={() => void join()} />}</ScreenShell></LiveBackground>;
}
function Row({ label, value }: { label: string; value: string }) { return <View style={{ alignItems: "center", borderBottomColor: colors.border, borderBottomWidth: 1, flexDirection: "row", justifyContent: "space-between", paddingBottom: spacing.sm }}><Text style={{ ...typography.body, color: colors.textSecondary }}>{label}</Text><Text selectable style={{ ...typography.headline, color: colors.textPrimary }}>{value}</Text></View>; }
