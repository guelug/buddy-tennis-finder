import { useEffect, useState } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Image, Pressable, Text, View } from "react-native";
import { colors, radii, shadows, spacing, typography } from "@/theme";

export type MatchBuddyId = "mia" | "mateo";

const STORAGE_KEY = "matchpoint-match-buddy";
const DEFAULT_BUDDY: MatchBuddyId = "mia";
const buddyListeners = new Set<(buddy: MatchBuddyId) => void>();

export const MATCH_BUDDIES = {
  mia: {
    id: "mia",
    name: "Mia",
    image: require("@/../assets/generated/match-buddy/mia.png")
  },
  mateo: {
    id: "mateo",
    name: "Mateo",
    image: require("@/../assets/generated/match-buddy/mateo.png")
  }
} satisfies Record<MatchBuddyId, { id: MatchBuddyId; name: string; image: number }>;

export function useMatchBuddy() {
  const [buddyId, setBuddyIdState] = useState<MatchBuddyId>(DEFAULT_BUDDY);

  useEffect(() => {
    void AsyncStorage.getItem(STORAGE_KEY).then((stored) => {
      if (stored === "mia" || stored === "mateo") setBuddyIdState(stored);
    }).catch(() => {});
    const listener = (next: MatchBuddyId) => setBuddyIdState(next);
    buddyListeners.add(listener);
    return () => { buddyListeners.delete(listener); };
  }, []);

  const setBuddyId = (next: MatchBuddyId) => {
    setBuddyIdState(next);
    buddyListeners.forEach((listener) => listener(next));
    void AsyncStorage.setItem(STORAGE_KEY, next).catch(() => {});
  };

  return { buddy: MATCH_BUDDIES[buddyId], buddyId, setBuddyId };
}

export function MatchBuddyAvatar({ size = 46 }: { size?: number }) {
  const { buddy } = useMatchBuddy();
  return (
    <View style={{ borderColor: `${colors.neon}88`, borderRadius: size / 2, borderWidth: 2, boxShadow: shadows.courtGlow, height: size, overflow: "hidden", width: size }}>
      <Image accessibilityLabel={`Match Buddy ${buddy.name}`} source={buddy.image} style={{ height: "100%", width: "100%" }} />
    </View>
  );
}

export function MatchBuddyPicker({ compact = false }: { compact?: boolean }) {
  const { buddyId, setBuddyId } = useMatchBuddy();
  return (
    <View style={{ gap: spacing.md }}>
      <View style={{ gap: spacing.xs }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>Elige tu Match Buddy</Text>
        <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
          Será tu compañero de IA privado para estadísticas, partidos y torneos. Puedes cambiarlo cuando quieras.
        </Text>
      </View>
      <View style={{ flexDirection: "row", gap: spacing.md }}>
        {(Object.values(MATCH_BUDDIES) as Array<(typeof MATCH_BUDDIES)[MatchBuddyId]>).map((buddy) => {
          const active = buddy.id === buddyId;
          return (
            <Pressable
              key={buddy.id}
              accessibilityRole="radio"
              accessibilityState={{ checked: active }}
              onPress={() => setBuddyId(buddy.id)}
              style={{
                alignItems: "center",
                backgroundColor: active ? `${colors.neon}18` : colors.surface,
                borderColor: active ? colors.neon : colors.borderStrong,
                borderCurve: "continuous",
                borderRadius: radii.lg,
                borderWidth: active ? 2 : 1,
                flex: 1,
                gap: spacing.sm,
                minHeight: compact ? 108 : 138,
                padding: spacing.sm
              }}
            >
              <Image source={buddy.image} style={{ borderRadius: compact ? 34 : 42, height: compact ? 68 : 84, width: compact ? 68 : 84 }} />
              <Text style={{ ...typography.bodyEmphasized, color: active ? colors.neon : colors.textPrimary }}>{buddy.name}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}
