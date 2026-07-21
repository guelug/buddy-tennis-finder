import { useEffect, useState } from "react";
import { Text, View } from "react-native";
import { Avatar } from "@/components/avatar";
import { Icon } from "@/components/icon";
import { ScreenShell } from "@/components/screen-shell";
import { LiveBackground } from "@/components/live-visuals";
import { markCoachInterestRead, subscribeToCoachInterests } from "@/lib/community";
import { useAuth } from "@/lib/firebase-auth";
import { colors, radii, spacing, typography } from "@/theme";
import type { CoachInterest } from "@/types";

export default function CoachInterestsScreen() {
  const { user } = useAuth();
  const [items, setItems] = useState<CoachInterest[]>([]);
  useEffect(() => user?.uid ? subscribeToCoachInterests(user.uid, (values) => {
    setItems(values);
    values.filter((item) => !item.readAt).forEach((item) => void markCoachInterestRead(item.id));
  }) : undefined, [user?.uid]);
  return <LiveBackground overlay={0.5}><ScreenShell><View style={{ gap: 4, paddingTop: spacing.lg }}><Text style={{ ...typography.caption, color: colors.neon, fontWeight: "900" }}>NUEVAS OPORTUNIDADES</Text><Text style={{ ...typography.title, color: colors.textPrimary }}>Jugadores interesados</Text></View>{items.length ? items.map((item) => <View key={item.id} style={{ alignItems: "center", backgroundColor: colors.surface, borderColor: item.readAt ? colors.border : colors.neon, borderRadius: radii.lg, borderWidth: 1, flexDirection: "row", gap: spacing.md, padding: spacing.lg }}><Avatar name={item.interestedName} photoURL={item.interestedPhotoURL} size={52} /><View style={{ flex: 1 }}><Text style={{ ...typography.headline, color: colors.textPrimary }}>{item.interestedName}</Text><Text style={{ ...typography.body, color: colors.textSecondary }}>Ha mostrado interés en tus clases.</Text><Text style={{ ...typography.footnote, color: colors.textTertiary }}>{new Date(item.createdAt).toLocaleDateString("es", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</Text></View><Icon name="tennis" size={23} color={colors.neon as string} /></View>) : <View style={{ alignItems: "center", gap: spacing.md, padding: spacing.xxl }}><Icon name="users" size={42} color={colors.textTertiary as string} /><Text style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>Cuando alguien pulse “Estoy interesado”, aparecerá aquí.</Text></View>}</ScreenShell></LiveBackground>;
}
