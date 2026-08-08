import { useEffect, useState } from "react";
import { Pressable, Text, TextInput, View } from "react-native";
import { router } from "expo-router";
import { Icon } from "@/components/icon";
import { LeagueCheckout } from "@/components/league-checkout";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { LiveBackground } from "@/components/live-visuals";
import { getPrivateLeague, subscribeToMyPrivateLeagues } from "@/lib/community";
import { useAuth } from "@/lib/firebase-auth";
import { shareLeagueInvite } from "@/lib/share";
import { colors, radii, spacing, typography } from "@/theme";
import type { Division, PrivateLeague, PrivateLeagueInput } from "@/types";

const levels: Division[] = ["novato", "d", "c", "b", "a"];
const inputStyle = { backgroundColor: colors.surfaceElevated, borderColor: colors.border, borderRadius: radii.md, borderWidth: 1, color: colors.textPrimary, fontSize: 16, minHeight: 50, paddingHorizontal: spacing.md, paddingVertical: spacing.sm } as const;

export default function PrivateLeaguesScreen() {
  const { user } = useAuth();
  const [leagues, setLeagues] = useState<PrivateLeague[]>([]);
  const [creating, setCreating] = useState(false);
  const [checkout, setCheckout] = useState<PrivateLeagueInput | null>(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [division, setDivision] = useState<Division>("novato");
  const [format, setFormat] = useState<"singles" | "doubles">("singles");

  useEffect(() => user?.uid ? subscribeToMyPrivateLeagues(user.uid, setLeagues) : undefined, [user?.uid]);
  const submit = () => {
    if (name.trim().length < 3) return;
    setCheckout({ name, description, division, format, maxMembers: format === "doubles" ? 16 : 12 });
  };
  const share = async (league: PrivateLeague) => {
    const fullLeague = await getPrivateLeague(league.id);
    if (fullLeague?.inviteCode) await shareLeagueInvite(fullLeague, user?.displayName || "Un amigo");
  };

  return <LiveBackground overlay={0.46}><ScreenShell width="wide"><View style={{ alignItems: "flex-start", flexDirection: "row", flexWrap: "wrap", gap: spacing.lg, justifyContent: "space-between", paddingTop: spacing.lg }}><View style={{ flex: 1, minWidth: 250 }}><Text style={{ ...typography.caption, color: colors.neon, fontWeight: "900", letterSpacing: 1.4 }}>TU CLUB PRIVADO</Text><Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 32 }}>Ligas con tus amigos</Text><Text style={{ ...typography.body, color: colors.textSecondary }}>Crea una liga permanente, comparte la invitación y reúne a tu grupo.</Text></View><PrimaryButton label={creating ? "Cerrar" : "Crear liga"} fullWidth={false} onPress={() => { setCreating((value) => !value); setCheckout(null); }} /></View>

  {creating ? <View style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.xl, borderWidth: 1, gap: spacing.md, padding: spacing.lg }}><Text style={{ ...typography.headline, color: colors.textPrimary }}>Nueva liga privada</Text>{checkout ? <LeagueCheckout input={checkout} onCreated={(id: string) => router.push({ pathname: "/private-league", params: { id } } as never)} /> : <><TextInput value={name} onChangeText={setName} placeholder="Nombre de la liga" placeholderTextColor={colors.textTertiary as string} style={inputStyle} /><TextInput value={description} onChangeText={setDescription} placeholder="Describe el reto o el grupo" placeholderTextColor={colors.textTertiary as string} multiline style={[inputStyle, { minHeight: 94, textAlignVertical: "top" }]} /><Text style={{ ...typography.caption, color: colors.textSecondary }}>Nivel</Text><View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>{levels.map((item) => <Option key={item} active={division === item} label={item === "novato" ? "Novato" : item.toUpperCase()} onPress={() => setDivision(item)} />)}</View><Text style={{ ...typography.caption, color: colors.textSecondary }}>Formato</Text><View style={{ flexDirection: "row", gap: spacing.xs }}><Option active={format === "singles"} label="Individual" onPress={() => setFormat("singles")} /><Option active={format === "doubles"} label="Dobles" onPress={() => setFormat("doubles")} /></View><PrimaryButton label="Continuar al pago" disabled={name.trim().length < 3} onPress={submit} /></>}</View> : null}

  <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.md }}>{leagues.length ? leagues.map((league) => <View key={league.id} style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.xl, borderWidth: 1, flexBasis: 300, flexGrow: 1, gap: spacing.md, padding: spacing.lg }}><View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}><View style={{ backgroundColor: colors.courtLight, borderRadius: radii.pill, paddingHorizontal: spacing.sm, paddingVertical: 4 }}><Text style={{ ...typography.footnote, color: colors.neon, fontWeight: "900" }}>LIGA PRIVADA</Text></View><Text style={{ ...typography.caption, color: colors.textSecondary }}>{league.memberIds.length}/{league.maxMembers}</Text></View><Text style={{ ...typography.title, color: colors.textPrimary, fontSize: 24 }}>{league.name}</Text><Text numberOfLines={3} style={{ ...typography.body, color: colors.textSecondary }}>{league.description || "Tu competición privada en MP Tennis League App."}</Text><View style={{ flexDirection: "row", gap: spacing.sm }}><PrimaryButton label="Abrir" fullWidth={false} onPress={() => router.push({ pathname: "/private-league", params: { id: league.id } } as never)} style={{ flex: 1 }} /><Pressable accessibilityLabel="Compartir liga" onPress={() => void share(league)} style={{ alignItems: "center", backgroundColor: colors.courtLight, borderRadius: radii.md, justifyContent: "center", width: 52 }}><Icon name="send" size={20} color={colors.neon as string} /></Pressable></View></View>) : <View style={{ alignItems: "center", flex: 1, gap: spacing.md, padding: spacing.xxl }}><Icon name="trophy" size={44} color={colors.textTertiary as string} /><Text style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>Todavía no perteneces a ninguna liga privada.</Text></View>}</View>
  </ScreenShell></LiveBackground>;
}

function Option({ active, label, onPress }: { active: boolean; label: string; onPress: () => void }) {
  return <Pressable onPress={onPress} style={{ backgroundColor: active ? colors.courtLight : colors.surfaceElevated, borderColor: active ? colors.neon : colors.border, borderRadius: radii.pill, borderWidth: 1, minHeight: 40, paddingHorizontal: spacing.md, justifyContent: "center" }}><Text style={{ ...typography.caption, color: active ? colors.neon : colors.textSecondary, fontWeight: "800" }}>{label}</Text></Pressable>;
}
