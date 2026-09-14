import { useEffect, useState } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Pressable, Text, View } from "react-native";
import { Image } from "expo-image";
import { colors, radii, shadows, spacing, typography } from "@/theme";
import { useI18n } from "@/lib/i18n";

// Los ids se mantienen estables para no romper la elección guardada en
// instalaciones existentes. El nombre visible sí es parte de la experiencia.
export type MatchBuddyId = "mia" | "mateo";

const STORAGE_KEY = "matchpoint-match-buddy";
const DEFAULT_BUDDY: MatchBuddyId = "mia";
const buddyListeners = new Set<(buddy: MatchBuddyId) => void>();
let selectedBuddy: MatchBuddyId | null = null;
let restoreBuddy: Promise<void> | null = null;
let persistBuddy = Promise.resolve();

export const MATCH_BUDDIES = {
  mia: {
    id: "mia",
    name: "Andrea",
    // Ruta relativa: Metro registra siempre estos assets locales en iOS y Android.
    image: require("../../assets/generated/match-buddy/andrea.png")
  },
  mateo: {
    id: "mateo",
    name: "Faker",
    image: require("../../assets/generated/match-buddy/faker.png")
  }
} satisfies Record<MatchBuddyId, { id: MatchBuddyId; name: string; image: number }>;

export function useMatchBuddy() {
  const [buddyId, setBuddyIdState] = useState<MatchBuddyId>(selectedBuddy ?? DEFAULT_BUDDY);

  useEffect(() => {
    const listener = (next: MatchBuddyId) => setBuddyIdState(next);
    buddyListeners.add(listener);
    if (selectedBuddy) listener(selectedBuddy);
    if (!restoreBuddy) {
      restoreBuddy = AsyncStorage.getItem(STORAGE_KEY).then((stored) => {
        // Una elección reciente gana a cualquier lectura antigua del disco.
        if (selectedBuddy === null) {
          selectedBuddy = stored === "mia" || stored === "mateo" ? stored : DEFAULT_BUDDY;
          buddyListeners.forEach((notify) => notify(selectedBuddy!));
        }
      }).catch(() => {});
    }
    return () => { buddyListeners.delete(listener); };
  }, []);

  const setBuddyId = (next: MatchBuddyId) => {
    selectedBuddy = next;
    setBuddyIdState(next);
    buddyListeners.forEach((listener) => listener(next));
    persistBuddy = persistBuddy.then(() => AsyncStorage.setItem(STORAGE_KEY, next)).catch(() => {});
  };

  return { buddy: MATCH_BUDDIES[buddyId], buddyId, setBuddyId };
}

export function MatchBuddyAvatar({ size = 46 }: { size?: number }) {
  const { buddy } = useMatchBuddy();
  return (
    <View style={{ borderColor: `${colors.neon}88`, borderRadius: size / 2, borderWidth: 2, boxShadow: shadows.courtGlow, height: size, overflow: "hidden", width: size }}>
      <Image accessibilityLabel={`Match Buddy ${buddy.name}`} contentFit="cover" source={buddy.image} style={{ height: "100%", width: "100%" }} />
    </View>
  );
}

export function MatchBuddyPicker({ compact = false }: { compact?: boolean }) {
  const { t } = useI18n();
  const { buddyId, setBuddyId } = useMatchBuddy();
  return (
    <View style={{ gap: spacing.md }}>
      <View style={{ gap: spacing.xs }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("onboarding.q.buddy.title")}</Text>
        <Text style={{ ...typography.footnote, color: colors.textSecondary }}>
          {t("assistant.disclaimer")}
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
              <Image
                accessibilityLabel={`${buddy.name}, Match Buddy`}
                contentFit="cover"
                source={buddy.image}
                style={{ borderRadius: compact ? 34 : 42, height: compact ? 68 : 84, width: compact ? 68 : 84 }}
              />
              <Text style={{ ...typography.bodyEmphasized, color: active ? colors.neon : colors.textPrimary }}>{buddy.name}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}
